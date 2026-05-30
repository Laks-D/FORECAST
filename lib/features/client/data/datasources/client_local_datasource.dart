import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../../../../core/app/app_mode.dart';
import '../../../../core/app/student_enrollment_resolver.dart';
import '../../../../core/firebase/firestore_db.dart';

/// Firestore-backed client datasource.
class ClientLocalDataSource {
  /// Monotonic counter to guarantee unique IDs even in tight loops.
  static int _idSeq = 0;

  static String _nextId() {
    _idSeq++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_idSeq';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final List<Client> _data = [];
  final List<Client> _deleted = [];

  List<Client> fetchClients() => _data;

  List<Client> fetchDeletedClients() => _deleted;

  Future<CollectionReference<Map<String, dynamic>>?> _collection({bool deleted = false}) async {
    String? targetUid;
    if (AppModeConfig.isClient) {
      targetUid = await StudentEnrollmentResolver.getTargetUid();
    } else {
      targetUid = FirebaseAuth.instance.currentUser?.uid;
    }
    if (targetUid == null || targetUid.trim().isEmpty) return null;
    final userDoc = firestoreDb.collection('users').doc(targetUid);
    return userDoc.collection(deleted ? 'deleted_clients' : 'clients');
  }

  Future<DocumentReference<Map<String, dynamic>>?> _doc(String id, {bool deleted = false}) async {
    final col = await _collection(deleted: deleted);
    return col?.doc(id);
  }

  Future<void> _persistClient(Client client, {bool deleted = false}) async {
    final ref = await _doc(client.id, deleted: deleted);
    if (ref == null) return;
    final json = client.toJson();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(json, SetOptions(merge: true));
  }

  /* ================= CRUD ================= */

  void deleteClient(String entityId) {
    final idx = _data.indexWhere((e) => e.id == entityId);
    if (idx == -1) return;
    final client = _data.removeAt(idx);
    _deleted.add(client);

    unawaited(_persistClient(client, deleted: true));
    unawaited(_doc(entityId).then((ref) => ref?.delete()));
  }

  void restoreClient(String entityId) {
    final idx = _deleted.indexWhere((e) => e.id == entityId);
    if (idx == -1) return;
    final client = _deleted.removeAt(idx);
    _data.add(client);

    unawaited(_persistClient(client));
    unawaited(_doc(entityId, deleted: true).then((ref) => ref?.delete()));
  }

  void addNote(String entityId, String note, {DateTime? createdAt}) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    entity.timeline.add(
      ClientTimelineEvent.note(
        id: _nextId(),
        note: note,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );

    unawaited(_persistClient(entity));
  }

  void addPayment({
    required String entityId,
    required double amount,
    String? note,
    DateTime? scheduledAt,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    entity.timeline.add(
      ClientTimelineEvent.payment(
        id: _nextId(),
        amount: amount,
        note: note,
        createdAt: scheduledAt ?? DateTime.now(),
      ),
    );

    unawaited(_persistClient(entity));
  }

  void addStatusChange({
    required String entityId,
    required String status,
    DateTime? createdAt,
    String? refId,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: _nextId(),
        status: status,
        createdAt: createdAt ?? DateTime.now(),
        refId: refId,
      ),
    );

    unawaited(_persistClient(entity));
  }

  void clearPaymentStatusesForDate({
    required String entityId,
    required DateTime date,
    String? paymentId,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);
    entity.timeline.removeWhere((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      if (!_sameDay(e.createdAt, date)) return false;
      if (paymentId != null && e.refId != paymentId && e.refId != null) {
        return false;
      }
      final s = e.status;
      return s == 'Paid' ||
          s == 'Paid fully' ||
          s == 'Will pay later' ||
          s == 'Unpaid';
    });

    unawaited(_persistClient(entity));
  }

  void reschedulePayment({
    required String entityId,
    required String paymentId,
    required DateTime oldDate,
    required DateTime newDate,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    ClientTimelineEvent? old;
    try {
      old = entity.timeline.firstWhere(
        (e) => e.type == ClientTimelineEventType.payment && e.id == paymentId,
      );
    } catch (_) {
      return;
    }

    final oldDay = DateTime(old.createdAt.year, old.createdAt.month, old.createdAt.day);
    final newDay = DateTime(newDate.year, newDate.month, newDate.day);

    final hadPaidMarker = entity.timeline.any((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      if (!_sameDay(e.createdAt, oldDay)) return false;
      if (e.refId != paymentId) return false;
      final s = e.status?.trim();
      return s == 'Paid' || s == 'Paid fully';
    });

    clearPaymentStatusesForDate(
      entityId: entityId,
      date: oldDay,
      paymentId: paymentId,
    );

    entity.timeline.remove(old);

    entity.timeline.add(
      ClientTimelineEvent.payment(
        id: old.id,
        amount: old.amount ?? 0,
        createdAt: newDay,
        note: old.note,
      ),
    );

    if (hadPaidMarker) {
      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Paid',
          createdAt: newDay,
          refId: paymentId,
        ),
      );
    } else {
      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Unpaid',
          createdAt: newDay,
          refId: paymentId,
        ),
      );
    }

    unawaited(_persistClient(entity));
  }

  void revertPaidFully({required String entityId}) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    final fullyEvent = entity.timeline.cast<ClientTimelineEvent?>().firstWhere(
          (e) =>
              e!.type == ClientTimelineEventType.statusChanged &&
              e.status?.trim() == 'Paid fully',
          orElse: () => null,
        );
    if (fullyEvent == null) return;

    final aggregatePaymentId = fullyEvent.refId;
    if (aggregatePaymentId != null) {
      entity.timeline.removeWhere((e) {
        if (e.type == ClientTimelineEventType.payment && e.id == aggregatePaymentId) {
          return true;
        }
        if (e.type == ClientTimelineEventType.statusChanged &&
            e.status?.trim() == 'Paid' &&
            e.refId == aggregatePaymentId) {
          return true;
        }
        return false;
      });

      entity.timeline.removeWhere((e) => e.id == fullyEvent.id);
      unawaited(_persistClient(entity));
      return;
    }

    final baseDay = DateTime(
      fullyEvent.createdAt.year,
      fullyEvent.createdAt.month,
      fullyEvent.createdAt.day,
    );

    entity.timeline.removeWhere((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      final s = e.status?.trim();
      if (s == 'Paid fully') return true;
      if (s != 'Paid') return false;
      final eDay = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      return !eDay.isBefore(baseDay);
    });

    unawaited(_persistClient(entity));
  }

  void markPaidFully({
    required String entityId,
    required DateTime fromDate,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);
    final baseDay = DateTime(fromDate.year, fromDate.month, fromDate.day);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isPaymentPaid(ClientTimelineEvent payment) {
      final dateKey = DateTime(
        payment.createdAt.year,
        payment.createdAt.month,
        payment.createdAt.day,
      );

      final hasMultiplePaymentsThatDay = entity.timeline
              .where((e) =>
                  e.type == ClientTimelineEventType.payment &&
                  _sameDay(e.createdAt, dateKey))
              .length >
          1;

      for (final e in entity.timeline.reversed) {
        if (e.type != ClientTimelineEventType.statusChanged) continue;
        if (!_sameDay(e.createdAt, dateKey)) continue;
        if (e.refId != payment.id) continue;
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully') return true;
      }

      if (!hasMultiplePaymentsThatDay) {
        for (final e in entity.timeline.reversed) {
          if (e.type != ClientTimelineEventType.statusChanged) continue;
          if (!_sameDay(e.createdAt, dateKey)) continue;
          if (e.refId != null) continue;
          final s = e.status?.trim();
          if (s == 'Paid' || s == 'Paid fully') return true;
        }
      }

      return false;
    }

    entity.timeline.removeWhere((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      final s = e.status?.trim();
      if (s != 'Paid fully') return false;
      return _sameDay(e.createdAt, baseDay) || _sameDay(e.createdAt, today);
    });

    final remainingPayments = entity.timeline
        .where((e) {
          if (e.type != ClientTimelineEventType.payment) return false;
          final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
          return !d.isBefore(baseDay);
        })
        .where((e) => !isPaymentPaid(e))
        .toList(growable: false);

    final total = remainingPayments.fold<double>(
      0,
      (sum, e) => sum + (e.amount ?? 0),
    );

    for (final pay in remainingPayments) {
      clearPaymentStatusesForDate(
        entityId: entityId,
        date: pay.createdAt,
        paymentId: pay.id,
      );
      entity.timeline.remove(pay);
    }

    if (total <= 0) {
      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Paid fully',
          createdAt: today,
          refId: null,
        ),
      );
      unawaited(_persistClient(entity));
      return;
    }

    final aggregatePaymentId = _nextId();

    entity.timeline.add(
      ClientTimelineEvent.payment(
        id: aggregatePaymentId,
        amount: total,
        createdAt: today,
        note: 'Paid fully',
      ),
    );

    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: _nextId(),
        status: 'Paid',
        createdAt: today,
        refId: aggregatePaymentId,
      ),
    );

    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: _nextId(),
        status: 'Paid fully',
        createdAt: today,
        refId: aggregatePaymentId,
      ),
    );

    unawaited(_persistClient(entity));
  }

  void updateClientDetails({
    required String entityId,
    required String name,
    required String primaryContact,
    String? firebaseUid,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? currency,
  }) {
    final idx = _data.indexWhere((e) => e.id == entityId);
    if (idx == -1) return;

    final existing = _data[idx];
    final updated = Client(
      id: existing.id,
      firebaseUid: firebaseUid ?? existing.firebaseUid,
      name: name,
      middleName: middleName ?? existing.middleName,
      primaryContact: primaryContact,
      countryCode: countryCode ?? existing.countryCode,
      email: email ?? existing.email,
      gender: gender ?? existing.gender,
      dateOfBirth: dateOfBirth ?? existing.dateOfBirth,
      address: address ?? existing.address,
      currency: currency ?? existing.currency,
      timeline: existing.timeline,
    );
    _data[idx] = updated;

    unawaited(_persistClient(updated));
  }

  void addClient({
    required String name,
    required String primaryContact,
    String? firebaseUid,
    String? referredBy,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
    String? currency,
  }) {
    // Deduplicate: If a client with the same UID, Phone, or Email already exists,
    // do not create a duplicate. Just patch the firebaseUid if it's missing.
    final normPhone = primaryContact.replaceAll(RegExp(r'\D'), '');
    final normEmail = email?.trim().toLowerCase();
    
    final existingIdx = _data.indexWhere((c) {
      if (firebaseUid != null && c.firebaseUid == firebaseUid) return true;
      
      final cPhone = c.primaryContact.replaceAll(RegExp(r'\D'), '');
      if (normPhone.isNotEmpty && cPhone == normPhone) return true;
      
      final cEmail = c.email?.trim().toLowerCase();
      if (normEmail != null && normEmail.isNotEmpty && cEmail == normEmail) return true;
      
      return false;
    });

    if (existingIdx >= 0) {
      final existing = _data[existingIdx];
      if (existing.firebaseUid == null && firebaseUid != null) {
        final updated = Client(
          id: existing.id,
          firebaseUid: firebaseUid,
          name: existing.name,
          middleName: existing.middleName,
          primaryContact: existing.primaryContact,
          countryCode: existing.countryCode,
          email: existing.email,
          gender: existing.gender,
          dateOfBirth: existing.dateOfBirth,
          address: existing.address,
          currency: existing.currency,
          timeline: existing.timeline,
        );
        _data[existingIdx] = updated;
        unawaited(_persistClient(updated));
      }
      return;
    }

    final client = Client(
      id: _nextId(),
      firebaseUid: firebaseUid,
      name: name,
      middleName: middleName,
      primaryContact: primaryContact,
      countryCode: countryCode,
      email: email,
      gender: gender,
      dateOfBirth: dateOfBirth,
      address: address,
      currency: currency,
      timeline: [
        ClientTimelineEvent.profileCreated(
          id: _nextId(),
          createdAt: DateTime.now(),
        ),
        if (referredBy != null)
          ClientTimelineEvent.note(
            id: _nextId(),
            note: 'Referred by: $referredBy',
            createdAt: DateTime.now(),
          ),
      ],
    );
    _data.add(client);

    unawaited(_persistClient(client));
  }

  /* ================= PERSISTENCE ================= */

  Future<void> persist() async {
    return;
  }

  Future<void> loadFromStorage() async {
    // Wait for Firebase Auth to complete its initial sync
    // This prevents a race condition on cold startup where currentUser is temporarily null
    await FirebaseAuth.instance.authStateChanges().first;

    final col = await _collection();
    if (col == null) {
      _data.clear();
      _deleted.clear();
      return;
    }

    final deletedCol = await _collection(deleted: true);

    try {
      final snap = await col.get();
      _data
        ..clear()
        ..addAll(
          snap.docs.map((doc) {
            final json = Map<String, dynamic>.from(doc.data());
            json['id'] = json['id'] ?? doc.id;
            return Client.fromJson(json);
          }),
        );
    } catch (_) {
      _data.clear();
    }

    try {
      if (deletedCol != null) {
        final deletedSnap = await deletedCol.get();
        _deleted
          ..clear()
          ..addAll(
            deletedSnap.docs.map((doc) {
                  final json = Map<String, dynamic>.from(doc.data());
                  json['id'] = json['id'] ?? doc.id;
                  return Client.fromJson(json);
                }),
          );
      }
    } catch (_) {
      _deleted.clear();
    }
  }
}
