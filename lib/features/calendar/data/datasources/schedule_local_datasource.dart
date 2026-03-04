import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/schedule_session.dart';

class ScheduleLocalDataSource {
  static const _storageKey = 'sessions_data_v1';

  final List<ScheduleSession> _sessions = [];
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

  Future<void> deleteSession(int id) async {
    _sessions.removeWhere((s) => s.id == id);
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
  }

  /// Load all sessions from SharedPreferences into memory.
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _sessions.clear();
      for (final item in decoded) {
        _sessions.add(ScheduleSession.fromJson(item as Map<String, dynamic>));
      }
      _controller.add(List.unmodifiable(_sessions));
    } catch (_) {
      // Ignore corrupt data.
    }
  }
}
