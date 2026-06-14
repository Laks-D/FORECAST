import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../../../../core/app/app_mode.dart';
import '../../../../core/app/student_enrollment_resolver.dart';
import '../../../../core/firebase/firestore_db.dart';
import '../../../payment/domain/entities/payment.dart';
import '../../../payment/domain/repositories/payment_repository.dart';
import '../../../payment/data/firestore_payment_repository.dart';
import '../../domain/entities/client_event.dart';
import '../client_event_repository.dart';

/// Firestore-backed client datasource.
class ClientLocalDataSource {
  ClientLocalDataSource({
    PaymentRepository? payments,
    ClientEventRepository? events,
  })  : _payments = payments ?? FirestorePaymentRepository(),
        _events = events ?? FirestoreClientEventRepository();

  /// Phase 3 dual-write target. The legacy client `timeline[]` remains the
  /// source of truth for reads; every payment lifecycle event is additionally
  /// mirrored into the first-class `payments` sub-collection. Guarded so a
  /// mirror failure never affects the existing flow.
  final PaymentRepository _payments;

  /// Phase 4 dual-write target for notes + status changes (not payments).
  final ClientEventRepository _events;

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
    final original = _data.removeAt(idx);
    // Stamp the deletion time for the 30-day auto-purge countdown.
    final client = Client(
      id: original.id,
      firebaseUid: original.firebaseUid,
      name: original.name,
      middleName: original.middleName,
      primaryContact: original.primaryContact,
      countryCode: original.countryCode,
      email: original.email,
      gender: original.gender,
      dateOfBirth: original.dateOfBirth,
      address: original.address,
      currency: original.currency,
      timeline: original.timeline,
      deletedAt: DateTime.now(),
    );
    _deleted.add(client);

    unawaited(_persistClient(client, deleted: true));
    unawaited(_doc(entityId).then((ref) => ref?.delete()));
  }

  /// Hard-deletes a client that is already in the soft-deleted list.
  /// Removes from Firestore immediately — cannot be undone.
  Future<void> permanentlyDeleteClient(String entityId) async {
    _deleted.removeWhere((e) => e.id == entityId);
    final ref = await _doc(entityId, deleted: true);
    await ref?.delete();
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

    final eventId = _nextId();
    final at = createdAt ?? DateTime.now();
    entity.timeline.add(
      ClientTimelineEvent.note(
        id: eventId,
        note: note,
        createdAt: at,
      ),
    );

    unawaited(_persistClient(entity));
    // Phase 4 dual-write: mirror the note into client_events.
    _mirrorClientEvent(
      eventId: eventId,
      entity: entity,
      type: ClientEventType.note,
      note: note,
      at: at,
    );
  }

  /* ================= CLIENT_EVENTS DUAL-WRITE (Phase 4) ================= */

  void _mirrorClientEvent({
    required String eventId,
    required Client entity,
    required ClientEventType type,
    String? note,
    String? status,
    required DateTime at,
  }) {
    try {
      if (AppModeConfig.isClient) return;
      final tutorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (tutorUid.isEmpty) return;
      unawaited(_events.add(ClientEvent(
        eventId: eventId,
        clientId: entity.id,
        tutorId: tutorUid,
        firebaseUid: entity.firebaseUid,
        type: type,
        note: note,
        status: status,
        createdAt: at,
      )));
    } catch (_) {}
  }

  void addPayment({
    required String entityId,
    required double amount,
    String? note,
    DateTime? scheduledAt,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    final paymentId = _nextId();
    final due = scheduledAt ?? DateTime.now();
    entity.timeline.add(
      ClientTimelineEvent.payment(
        id: paymentId,
        amount: amount,
        note: note,
        createdAt: due,
      ),
    );

    unawaited(_persistClient(entity));
    // Phase 3 dual-write: mirror into the payments sub-collection.
    _mirrorPaymentAdd(
      paymentId: paymentId,
      entity: entity,
      amount: amount,
      dueDate: due,
      note: note,
    );
  }

  /* ================= PAYMENTS DUAL-WRITE (Phase 3) ================= */

  void _mirrorPaymentAdd({
    required String paymentId,
    required Client entity,
    required double amount,
    required DateTime dueDate,
    String? note,
  }) {
    try {
      if (AppModeConfig.isClient) return; // only the tutor owns the ledger
      final tutorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (tutorUid.isEmpty) return;
      unawaited(_payments.add(Payment(
        paymentId: paymentId,
        tutorId: tutorUid,
        clientId: entity.id,
        firebaseUid: entity.firebaseUid,
        amount: amount,
        currency: entity.currency,
        status: PaymentStatus.unpaid,
        dueDate: dueDate,
        note: note,
      )));
    } catch (_) {
      // Non-critical mirror.
    }
  }

  static const _paymentStatuses = {
    'paid',
    'unpaid',
    'will pay later',
    'paid fully',
  };

  void _mirrorPaymentStatus(String? paymentId, String status) {
    try {
      if (paymentId == null || paymentId.isEmpty) return;
      if (AppModeConfig.isClient) return;
      // Only mirror genuine payment-status changes (client status changes like
      // Active/Inactive also flow through here but carry no payment refId match).
      if (!_paymentStatuses.contains(status.trim().toLowerCase())) return;
      unawaited(_payments.setStatus(paymentId, PaymentStatus.fromName(status)));
    } catch (_) {}
  }

  void addStatusChange({
    required String entityId,
    required String status,
    DateTime? createdAt,
    String? refId,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    final eventId = _nextId();
    final at = createdAt ?? DateTime.now();
    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: eventId,
        status: status,
        createdAt: at,
        refId: refId,
      ),
    );

    unawaited(_persistClient(entity));
    // Phase 3 dual-write: mirror payment-status changes onto the payment doc.
    _mirrorPaymentStatus(refId, status);
    // Phase 4 dual-write: mirror genuine client status changes (Active /
    // Inactive / On Hold / Pending) into client_events. Payment statuses are
    // handled by the payments mirror above, not here.
    if (!_paymentStatuses.contains(status.trim().toLowerCase())) {
      _mirrorClientEvent(
        eventId: eventId,
        entity: entity,
        type: ClientEventType.statusChanged,
        status: status,
        at: at,
      );
    }
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
    // Phase 3 dual-write: mirror the rescheduled due date + status.
    _mirrorPaymentReschedule(
      paymentId: paymentId,
      entity: entity,
      amount: old.amount ?? 0,
      newDue: newDay,
      paid: hadPaidMarker,
      note: old.note,
    );
  }

  void _mirrorPaymentReschedule({
    required String paymentId,
    required Client entity,
    required double amount,
    required DateTime newDue,
    required bool paid,
    String? note,
  }) {
    try {
      if (AppModeConfig.isClient) return;
      final tutorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (tutorUid.isEmpty) return;
      unawaited(_payments.update(Payment(
        paymentId: paymentId,
        tutorId: tutorUid,
        clientId: entity.id,
        firebaseUid: entity.firebaseUid,
        amount: amount,
        currency: entity.currency,
        status: paid ? PaymentStatus.paid : PaymentStatus.unpaid,
        dueDate: newDue,
        note: note,
      )));
    } catch (_) {}
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
    
    final deletedIdx = _deleted.indexWhere((c) {
      if (firebaseUid != null && c.firebaseUid == firebaseUid) return true;
      
      final cPhone = c.primaryContact.replaceAll(RegExp(r'\D'), '');
      final isDummyPhone = normPhone == '0000000000' || normPhone.isEmpty;
      if (!isDummyPhone && cPhone == normPhone) return true;
      
      final cEmail = c.email?.trim().toLowerCase();
      if (normEmail != null && normEmail.isNotEmpty && cEmail == normEmail) return true;
      
      return false;
    });

    if (deletedIdx >= 0) {
      final existing = _deleted.removeAt(deletedIdx);
      final updated = Client(
        id: existing.id,
        firebaseUid: firebaseUid ?? existing.firebaseUid,
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
        deletedAt: null, // RESTORE!
      );
      _data.add(updated);
      unawaited(_persistClient(updated));
      unawaited(_doc(existing.id, deleted: true).then((ref) => ref?.delete()));
      return;
    }

    final existingIdx = _data.indexWhere((c) {
      if (firebaseUid != null && c.firebaseUid == firebaseUid) return true;
      
      final cPhone = c.primaryContact.replaceAll(RegExp(r'\D'), '');
      final isDummyPhone = normPhone == '0000000000' || normPhone.isEmpty;
      if (!isDummyPhone && cPhone == normPhone) return true;
      
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
      final QuerySnapshot<Map<String, dynamic>> snap;
      if (AppModeConfig.isClient) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        snap = await firestoreDb
            .collectionGroup('clients')
            .where('firebaseUid', isEqualTo: uid)
            .get();
      } else {
        snap = await col.get();
      }
      _data
        ..clear()
        ..addAll(
          snap.docs.map((doc) {
            final json = Map<String, dynamic>.from(doc.data());
            json['id'] = json['id'] ?? doc.id;
            if (doc.reference.parent.parent != null) {
              json['tutorId'] = doc.reference.parent.parent!.id;
            }
            return Client.fromJson(json);
          }),
        );
    } catch (_) {
      _data.clear();
    }

    try {
      if (deletedCol != null) {
        final deletedSnap = await deletedCol.get();
        final now = DateTime.now();
        const purgeDays = 30;
        final toHardDelete = <String>[];

        _deleted
          ..clear()
          ..addAll(
            deletedSnap.docs.map((doc) {
              final json = Map<String, dynamic>.from(doc.data());
              json['id'] = json['id'] ?? doc.id;
              return Client.fromJson(json);
            }),
          );

        // Auto-purge: remove clients that have been deleted for > 30 days.
        // Legacy records with no deletedAt are NOT immediately purged —
        // they get a fresh 30-day window from now (patch deletedAt).
        for (final client in List<Client>.from(_deleted)) {
          if (client.deletedAt == null) {
            // Legacy: stamp deletedAt = now so they get a proper window.
            final patched = Client(
              id: client.id,
              firebaseUid: client.firebaseUid,
              name: client.name,
              middleName: client.middleName,
              primaryContact: client.primaryContact,
              countryCode: client.countryCode,
              email: client.email,
              gender: client.gender,
              dateOfBirth: client.dateOfBirth,
              address: client.address,
              currency: client.currency,
              timeline: client.timeline,
              deletedAt: now,
            );
            final idx = _deleted.indexWhere((e) => e.id == client.id);
            if (idx >= 0) _deleted[idx] = patched;
            unawaited(_persistClient(patched, deleted: true));
          } else if (now.difference(client.deletedAt!).inDays >= purgeDays) {
            toHardDelete.add(client.id);
            _deleted.removeWhere((e) => e.id == client.id);
          }
        }

        // Fire-and-forget hard deletes for expired records.
        for (final id in toHardDelete) {
          unawaited(deletedCol.doc(id).delete());
        }
      }
    } catch (_) {
      _deleted.clear();
    }
  }
}
