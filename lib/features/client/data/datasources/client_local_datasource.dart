import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../../../../core/services/user_firestore_sync.dart';

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
  }

  /// Remove payment-related status events (Paid / Paid fully / Will pay later)
  /// for a specific date on the given client.
  void clearPaymentStatusesForDate({
    required String entityId,
    required DateTime date,
    String? paymentId,
  }) {
    final entity = _data.firstWhere((e) => e.id == entityId);
    entity.timeline.removeWhere((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      if (!_sameDay(e.createdAt, date)) return false;
      // If a specific paymentId is provided, clear both the payment-specific
      // marker (refId == paymentId) AND any legacy date-scoped marker (refId == null)
      // because legacy markers make individual payments uneditable.
      if (paymentId != null && e.refId != paymentId && e.refId != null) {
        return false;
      }
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
    final baseDay = DateTime(fromDate.year, fromDate.month, fromDate.day);

    // Mark all payments on baseDay as paid (payment-specific).
    // This supports multiple payments on the same day while keeping each payment
    // individually editable.
    final paymentsOnBaseDay = entity.timeline
        .where((e) => e.type == ClientTimelineEventType.payment && _sameDay(e.createdAt, baseDay))
        .toList(growable: false);

    for (final pay in paymentsOnBaseDay) {
      // Clear any existing payment status markers for this payment on that day.
      clearPaymentStatusesForDate(
        entityId: entityId,
        date: pay.createdAt,
        paymentId: pay.id,
      );

      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Paid',
          createdAt: pay.createdAt,
          refId: pay.id,
        ),
      );
    }
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
    String? currency,
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
      currency: currency ?? existing.currency,
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
    String? currency,
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
        currency: currency,
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

    // Mirror into Firestore under the signed-in user.
    UserFirestoreSync.instance.scheduleClientsSync(List.unmodifiable(_data));
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

      // Legacy migration (one-time):
      // Older data used statuses: Pending (future) + Overdue (past-due).
      // New UI uses: Upcoming (future) + Pending (past-due).
      // We only migrate *client status* events (not payment statusChanged events).
      final hasLegacyOverdue = _data.any(
        (c) => c.timeline.any(
          (e) => e.type == ClientTimelineEventType.statusChanged &&
              (e.status?.trim() == 'Overdue'),
        ),
      );
      if (hasLegacyOverdue) {
        Client migrateClient(Client c) {
          ClientTimelineEvent migrateEvent(ClientTimelineEvent e) {
            if (e.type != ClientTimelineEventType.statusChanged) return e;
            final s = e.status?.trim();
            if (s == null || s.isEmpty) return e;

            // Don't touch payment-related statuses.
            if (s == 'Paid' || s == 'Paid fully' || s == 'Will pay later') return e;

            final mapped = (s == 'Overdue')
                ? 'Pending'
                : (s == 'Pending')
                    ? 'Upcoming'
                    : s;

            if (mapped == s) return e;
            return ClientTimelineEvent(
              id: e.id,
              type: e.type,
              createdAt: e.createdAt,
              amount: e.amount,
              note: e.note,
              status: mapped,
            );
          }

          final migratedTimeline = c.timeline.map(migrateEvent).toList();
          return Client(
            id: c.id,
            name: c.name,
            middleName: c.middleName,
            primaryContact: c.primaryContact,
            countryCode: c.countryCode,
            email: c.email,
            gender: c.gender,
            dateOfBirth: c.dateOfBirth,
            address: c.address,
            currency: c.currency,
            timeline: migratedTimeline,
          );
        }

        final migrated = _data.map(migrateClient).toList();
        _data
          ..clear()
          ..addAll(migrated);

        // Persist back so we don't need to migrate again.
        await persist();
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