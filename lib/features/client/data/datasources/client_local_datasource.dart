import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/client.dart';
import '../../domain/entities/client_timeline_event.dart';
import '../../../../core/services/user_firestore_sync.dart';

/// Local in-memory client datasource backed by SharedPreferences.
class ClientLocalDataSource {
  static const _storageKey = 'client_data_v1';
  static const _deletedStorageKey = 'client_deleted_v1';

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

  /// Soft-deleted clients (kept for restore)
  final List<Client> _deleted = [];

  /// Fetch all clients
  List<Client> fetchClients() => _data;

  /// Fetch soft-deleted clients
  List<Client> fetchDeletedClients() => const <Client>[];

  /// Soft delete a client by moving it into the deleted bucket.
  void deleteClient(String entityId) {
    final idx = _data.indexWhere((e) => e.id == entityId);
    if (idx == -1) return;
    _data.removeAt(idx);

    // Permanent delete: also ensure the client is not present in the legacy
    // deleted bucket (older app versions).
    _deleted.removeWhere((e) => e.id == entityId);
  }

  /// Restore a previously deleted client back into the active list.
  void restoreClient(String entityId) {
    // Restore is no longer supported (permanent delete).
    return;
  }

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
      return s == 'Paid' ||
          s == 'Paid fully' ||
          s == 'Will pay later' ||
          s == 'Unpaid';
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

    // Always resolve the payment by id and use its stored date.
    // The UI-provided oldDate can be stale (widget rebuilt, timezone parsing, etc.).
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

    // We intentionally do NOT keep "Will pay later" after a reschedule.
    // Once a new date is chosen, the payment becomes a normal unpaid item.

    // If the user previously marked this payment as paid, keep it paid after
    // moving the date. Otherwise rescheduling appears to "not work" because
    // it disappears from the Payment module list.
    final hadPaidMarker = entity.timeline.any((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      if (!_sameDay(e.createdAt, oldDay)) return false;
      if (e.refId != paymentId) return false;
      final s = e.status?.trim();
      return s == 'Paid' || s == 'Paid fully';
    });

    // Payment moved to a new day: clear any payment-related status markers
    // tied to the old day/payment id so the UI and payment module don't
    // keep showing stale Paid/Will pay later states.
    clearPaymentStatusesForDate(
      entityId: entityId,
      date: oldDay,
      paymentId: paymentId,
    );

    // Remove the old payment event and re-add it on the new day.
    // (We keep the same id so any status markers/refId remain valid.)
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
      // Force Pending status for rescheduled unpaid payments.
      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Unpaid',
          createdAt: newDay,
          refId: paymentId,
        ),
      );
    }
  }

  /// Revert a previous "Paid fully" action — removes the
  /// "Paid fully" status event and all "Paid" status events it generated.
  void revertPaidFully({required String entityId}) {
    final entity = _data.firstWhere((e) => e.id == entityId);

    // Find the "Paid fully" event.
    // New behavior stores a refId pointing at the aggregated payment event.
    // Legacy behavior stored only the base date.
    final fullyEvent = entity.timeline.cast<ClientTimelineEvent?>().firstWhere(
          (e) =>
              e!.type == ClientTimelineEventType.statusChanged &&
              e.status?.trim() == 'Paid fully',
          orElse: () => null,
        );
    if (fullyEvent == null) return;

    final aggregatePaymentId = fullyEvent.refId;
    if (aggregatePaymentId != null) {
      // Remove the aggregated payment event and its paid marker.
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

      // Remove the Paid fully marker itself.
      entity.timeline.removeWhere((e) => e.id == fullyEvent.id);
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
  }

  /// Mark all payments from [fromDate] onward as Paid and add a "Paid fully"
  /// status marker on [fromDate].
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

      // Prefer payment-specific status changes.
      for (final e in entity.timeline.reversed) {
        if (e.type != ClientTimelineEventType.statusChanged) continue;
        if (!_sameDay(e.createdAt, dateKey)) continue;
        if (e.refId != payment.id) continue;
        final s = e.status?.trim();
        if (s == 'Paid' || s == 'Paid fully') return true;
      }

      // Fallback to legacy date-based status changes (no refId).
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

    // Remove any existing "Paid fully" marker first (idempotent).
    entity.timeline.removeWhere((e) {
      if (e.type != ClientTimelineEventType.statusChanged) return false;
      final s = e.status?.trim();
      if (s != 'Paid fully') return false;
      // Remove both legacy (date-scoped) and new (refId-scoped) markers.
      return _sameDay(e.createdAt, baseDay) || _sameDay(e.createdAt, today);
    });

    // Combine remaining (unpaid) scheduled payments from baseDay onward into
    // a SINGLE payment recorded today.
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

    // Remove the pending scheduled payments and any payment-status markers tied
    // to them so they no longer show up as future schedule entries.
    for (final pay in remainingPayments) {
      clearPaymentStatusesForDate(
        entityId: entityId,
        date: pay.createdAt,
        paymentId: pay.id,
      );
      entity.timeline.remove(pay);
    }

    if (total <= 0) {
      // Nothing remaining to pay.
      // Still add a marker to reflect the user's intent.
      entity.timeline.add(
        ClientTimelineEvent.statusChange(
          id: _nextId(),
          status: 'Paid fully',
          createdAt: today,
          refId: null,
        ),
      );
      return;
    }

    final aggregatePaymentId = _nextId();

    // Create the aggregated payment event and mark it Paid.
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

    // Store a Paid fully marker pointing to the aggregated payment (supports
    // a best-effort revert that at least removes the aggregated record).
    entity.timeline.add(
      ClientTimelineEvent.statusChange(
        id: _nextId(),
        status: 'Paid fully',
        createdAt: today,
        refId: aggregatePaymentId,
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
    String? referredBy,
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
          if (referredBy != null)
            ClientTimelineEvent.note(
              id: _nextId(),
              note: 'Referred by: $referredBy',
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

    // Deleted clients are no longer persisted (permanent delete).
    await prefs.remove(_deletedStorageKey);

    // Mirror into Firestore under the signed-in user.
    UserFirestoreSync.instance.scheduleClientsSync(List.unmodifiable(_data));
  }

  /// Load all client data from SharedPreferences into memory.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final rawDeleted = prefs.getString(_deletedStorageKey);
    if ((raw == null || raw.trim().isEmpty) &&
        (rawDeleted == null || rawDeleted.trim().isEmpty)) {
      return;
    }
    try {
      _data.clear();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          _data.add(Client.fromJson(item as Map<String, dynamic>));
        }
      }

      _deleted.clear();
      // Migration: older versions stored deleted clients for restore.
      // Deletion is now permanent, so we drop that data.
      if (rawDeleted != null && rawDeleted.trim().isNotEmpty) {
        try {
          await prefs.remove(_deletedStorageKey);
        } catch (_) {}
      }

      // Legacy migration (one-time):
      // Older data used statuses: Pending (future) + Overdue (past-due).
      // New UI uses: Upcoming (future) + Pending (past-due).
      // We only migrate *client status* events (not payment statusChanged events).
      final hasLegacyOverdue = [..._data, ..._deleted].any(
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

        final migratedActive = _data.map(migrateClient).toList();
        _data
          ..clear()
          ..addAll(migratedActive);

        final migratedDeleted = _deleted.map(migrateClient).toList();
        _deleted
          ..clear()
          ..addAll(migratedDeleted);

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