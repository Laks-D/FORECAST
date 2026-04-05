import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/schedule_session.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/services/user_firestore_sync.dart';

class ScheduleLocalDataSource {
  static const _storageKey = 'sessions_data_v1';
  static const _deletedStorageKey = 'sessions_deleted_v1';

  final List<ScheduleSession> _sessions = [];
  final List<ScheduleSession> _deletedSessions = [];
  final StreamController<List<ScheduleSession>> _controller =
      StreamController<List<ScheduleSession>>.broadcast();

  Stream<List<ScheduleSession>> watchSessions() async* {
    yield List.unmodifiable(_sessions);
    yield* _controller.stream;
  }

  Future<void> addSession(ScheduleSession session) async {
    _sessions.add(session);
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> addSessions(List<ScheduleSession> sessions) async {
    _sessions.addAll(sessions);
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> updateSession(ScheduleSession session) async {
    final idx = _sessions.indexWhere((s) => s.id == session.id);
    if (idx < 0) return;
    _sessions[idx] = session;
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> updateSessions(List<ScheduleSession> sessions) async {
    if (sessions.isEmpty) return;

    var didChange = false;
    for (final session in sessions) {
      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx < 0) continue;
      _sessions[idx] = session;
      didChange = true;
    }

    if (!didChange) return;
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> deleteSession(int id) async {
    _sessions.removeWhere((s) => s.id == id);
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> deleteUpcomingSessionsForClient(String clientId) async {
    if (clientId.trim().isEmpty) return;

    final toDelete = <ScheduleSession>[];
    for (final s in _sessions) {
      if (s.clientId != clientId) continue;
      final derived = AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
      if (derived == 'Upcoming') {
        toDelete.add(s);
      }
    }

    if (toDelete.isEmpty) return;

    _sessions.removeWhere((s) => toDelete.any((d) => d.id == s.id));
    _deletedSessions.addAll(toDelete);
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> restoreDeletedUpcomingSessionsForClient(String clientId) async {
    if (clientId.trim().isEmpty) return;

    final restore = _deletedSessions.where((s) => s.clientId == clientId).toList();
    if (restore.isEmpty) return;

    final existingIds = _sessions.map((e) => e.id).toSet();
    for (final s in restore) {
      if (existingIds.contains(s.id)) continue;
      _sessions.add(s);
    }

    _deletedSessions.removeWhere((s) => s.clientId == clientId);
    _controller.add(List.unmodifiable(_sessions));
    await persist();
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  /* ================= PERSISTENCE ================= */

  /// Save all sessions to SharedPreferences.
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));

    final deletedJsonList = _deletedSessions.map((s) => s.toJson()).toList();
    await prefs.setString(_deletedStorageKey, jsonEncode(deletedJsonList));

    // Mirror into Firestore under the signed-in user.
    UserFirestoreSync.instance.scheduleSessionsSync(List.unmodifiable(_sessions));
  }

  /// Load all sessions from SharedPreferences into memory.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final rawDeleted = prefs.getString(_deletedStorageKey);
    if ((raw == null || raw.trim().isEmpty) &&
        (rawDeleted == null || rawDeleted.trim().isEmpty)) {
      return;
    }
    try {
      _sessions.clear();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          _sessions.add(ScheduleSession.fromJson(item as Map<String, dynamic>));
        }
      }

      _deletedSessions.clear();
      if (rawDeleted != null && rawDeleted.trim().isNotEmpty) {
        final decodedDeleted = jsonDecode(rawDeleted) as List<dynamic>;
        for (final item in decodedDeleted) {
          _deletedSessions.add(
            ScheduleSession.fromJson(item as Map<String, dynamic>),
          );
        }
      }
      _controller.add(List.unmodifiable(_sessions));
    } catch (_) {
      // Ignore corrupt data.
    }
  }
}
