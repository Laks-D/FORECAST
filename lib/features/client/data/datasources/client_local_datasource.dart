import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';

/// Local in-memory client datasource backed by SharedPreferences.
class ClientLocalDataSource {
  static const _storageKey = 'client_data_v1';

  /// Monotonic counter to guarantee unique IDs even in tight loops.
  static int _idSeq = 0;

  static String _nextId() {
    _idSeq++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_idSeq';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Internal mutable store
  final List<Client> _data = [];

  /// Fetch all clients
  List<Client> fetchClients() => _data;

  /// Add a note to an entity
  void addNote(String entityId, String note, {DateTime? createdAt}) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    entity.timeline.add(
      ClientTimelineEvent.note(
        id: _nextId(),
        note: note,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  /// Add a payment to an entity
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
  }

  /// Add a manual status change to an entity
  void addStatusChange({
    required String entityId,
    required String status,
    DateTime? createdAt,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: _nextId(),
        status: status,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  /// Remove payment-related status events (Paid / Paid fully / Will pay later)
  /// for a specific date on the given client.
  void clearPaymentStatusesForDate({
    required String entityId,
    required DateTime date,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);
    entity.timeline.removeWhere((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      if (!_sameDay(e.createdAt, date)) return false;
      final s = e.status;
      return s == 'Paid' || s == 'Paid fully' || s == 'Will pay later';
    });
  }

  /// Reschedule (simple move) a payment to a new date.
  void reschedulePayment({
    required String entityId,
    required String paymentId,
    required DateTime oldDate,
    required DateTime newDate,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    ClientTimelineEvent? old;
    for (final e in entity.timeline) {
      if (e.type != ClientTimelineEventType.payment) continue;
      if (e.id != paymentId) continue;
      if (_sameDay(e.createdAt, oldDate)) {
        old = e;
        break;
      }
    }
    old ??= entity.timeline.firstWhere(
      (e) => e.type == ClientTimelineEventType.payment && e.id == paymentId,
    );

    entity.timeline.remove(old);
    entity.timeline.add(
      ClientTimelineEvent.payment(
        id: old.id,
        amount: old.amount ?? 0,
        createdAt: newDate,
        note: old.note,
      ),
    );
  }

  /// Merge two payments into one on the target date.
  void mergePayments({
    required String entityId,
    required String sourcePaymentId,
    required DateTime sourceDate,
    required String targetPaymentId,
    required DateTime targetDate,
    required double mergedAmount,
    String? mergedNote,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    ClientTimelineEvent? source;
    ClientTimelineEvent? target;
    for (final e in entity.timeline) {
      if (e.type != ClientTimelineEventType.payment) continue;
      if (e.id == sourcePaymentId && _sameDay(e.createdAt, sourceDate)) {
        source = e;
      }
      if (e.id == targetPaymentId && _sameDay(e.createdAt, targetDate)) {
        target = e;
      }
    }
    source ??= entity.timeline.firstWhere(
      (e) => e.type == ClientTimelineEventType.payment && e.id == sourcePaymentId,
    );
    target ??= entity.timeline.firstWhere(
      (e) => e.type == ClientTimelineEventType.payment && e.id == targetPaymentId,
    );

    entity.timeline.remove(source);
    entity.timeline.remove(target);
    entity.timeline.add(
      ClientTimelineEvent.payment(
        id: target.id,
        amount: mergedAmount,
        createdAt: targetDate,
        note: mergedNote,
      ),
    );
  }

  /// Revert a previous "Paid fully" action — removes the
  /// "Paid fully" status event and all "Paid" status events it generated.
  void revertPaidFully({required String entityId}) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    // Find the "Paid fully" event to know the starting date.
    final fullyEvent = entity.timeline.cast<ClientTimelineEvent?>().firstWhere(
      (e) =>
          e!.type == ClientTimelineEventType.statusChanged &&
          e.status?.trim() == 'Paid fully',
      orElse: () => null,
    );
    if (fullyEvent == null) return;

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
  }

  /// Mark all payments from [fromDate] onward as Paid and add a "Paid fully"
  /// status marker on [fromDate].
  void markPaidFully({
    required String entityId,
    required DateTime fromDate,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);
    final payments = entity.timeline
        .where((e) => e.type == ClientTimelineEventType.payment)
        .toList(growable: false);

    for (final pay in payments) {
      final payDay = DateTime(pay.createdAt.year, pay.createdAt.month, pay.createdAt.day);
      final baseDay = DateTime(fromDate.year, fromDate.month, fromDate.day);
      if (payDay.isBefore(baseDay)) continue;

      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Paid',
          createdAt: payDay,
        ),
      );
    }

    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: _nextId(),
        status: 'Paid fully',
        createdAt: fromDate,
      ),
    );
  }

  /// Update client base details (name/contact)
  void updateClientDetails({
    required String entityId,
    required String name,
    required String primaryContact,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
  }) {
    final idx = _data.indexWhere((e) => e.id == entityId);
    if (idx == -1) return;

    final existing = _data[idx];
    _data[idx] = Client(
      id: existing.id,
      name: name,
      middleName: middleName ?? existing.middleName,
      primaryContact: primaryContact,
      countryCode: countryCode ?? existing.countryCode,
      email: email ?? existing.email,
      gender: gender ?? existing.gender,
      dateOfBirth: dateOfBirth ?? existing.dateOfBirth,
      address: address ?? existing.address,
      timeline: existing.timeline,
    );
  }

  /// Add a new client
  void addClient({
    required String name,
    required String primaryContact,
    String? middleName,
    String? countryCode,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? address,
  }) {
    _data.add(
      Client(
        id: _nextId(),
        name: name,
        middleName: middleName,
        primaryContact: primaryContact,
        countryCode: countryCode,
        email: email,
        gender: gender,
        dateOfBirth: dateOfBirth,
        address: address,
        timeline: [
          ClientTimelineEvent.profileCreated(
            id: _nextId(),
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  /* ================= PERSISTENCE ================= */

  /// Save all client data to SharedPreferences.
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _data.map((c) => c.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Load all client data from SharedPreferences into memory.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _data.clear();
      for (final item in decoded) {
        _data.add(Client.fromJson(item as Map<String, dynamic>));
      }
      // Ensure ID counter stays ahead of any loaded IDs.
      for (final c in _data) {
        final parts = c.id.split('_');
        if (parts.length == 2) {
          final seq = int.tryParse(parts[1]);
          if (seq != null && seq >= _idSeq) _idSeq = seq + 1;
        }
      }
    } catch (_) {
      // Ignore corrupt data.
    }
  }
}