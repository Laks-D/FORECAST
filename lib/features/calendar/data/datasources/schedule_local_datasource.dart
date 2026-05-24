import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/schedule_session.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/firebase/firestore_db.dart';

class ScheduleLocalDataSource {
  final List<ScheduleSession> _sessions = [];
  final List<ScheduleSession> _deletedSessions = [];

  CollectionReference<Map<String, dynamic>>? _sessionsCollection({bool deleted = false}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return null;
    final userDoc = firestoreDb.collection('users').doc(uid);
    return userDoc.collection(deleted ? 'deleted_sessions' : 'sessions');
  }

  Stream<List<ScheduleSession>> watchSessions() {
    final col = _sessionsCollection();
    if (col == null) return Stream.value(const <ScheduleSession>[]);

    return col.snapshots().map((snap) {
      final items = snap.docs.map((doc) {
        final json = Map<String, dynamic>.from(doc.data());
        json['id'] = json['id'] ?? int.tryParse(doc.id) ?? 0;
        return ScheduleSession.fromJson(json);
      }).toList(growable: false);

      _sessions
        ..clear()
        ..addAll(items);
      return List.unmodifiable(_sessions);
    });
  }

  Future<void> addSession(ScheduleSession session) async {
    _sessions.add(session);
    await _persistSession(session);
  }

  Future<void> addSessions(List<ScheduleSession> sessions) async {
    if (sessions.isEmpty) return;
    _sessions.addAll(sessions);
    final batch = firestoreDb.batch();
    final col = _sessionsCollection();
    if (col == null) return;
    final now = FieldValue.serverTimestamp();
    for (final s in sessions) {
      final ref = col.doc(s.id.toString());
      final json = s.toJson();
      json['updatedAt'] = now;
      batch.set(ref, json, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updateSession(ScheduleSession session) async {
    final idx = _sessions.indexWhere((s) => s.id == session.id);
    if (idx < 0) return;
    _sessions[idx] = session;
    await _persistSession(session);
  }

  Future<void> updateSessions(List<ScheduleSession> sessions) async {
    if (sessions.isEmpty) return;
    final col = _sessionsCollection();
    if (col == null) return;

    final batch = firestoreDb.batch();
    final now = FieldValue.serverTimestamp();
    for (final session in sessions) {
      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx < 0) continue;
      _sessions[idx] = session;
      final ref = col.doc(session.id.toString());
      final json = session.toJson();
      json['updatedAt'] = now;
      batch.set(ref, json, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> deleteSession(int id) async {
    _sessions.removeWhere((s) => s.id == id);
    final ref = _sessionsCollection()?.doc(id.toString());
    if (ref != null) await ref.delete();
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

    final sessionsCol = _sessionsCollection();
    final deletedCol = _sessionsCollection(deleted: true);
    if (sessionsCol == null || deletedCol == null) return;

    final batch = firestoreDb.batch();
    final now = FieldValue.serverTimestamp();
    for (final s in toDelete) {
      _sessions.removeWhere((e) => e.id == s.id);
      _deletedSessions.add(s);

      final json = s.toJson();
      json['updatedAt'] = now;
      batch.set(deletedCol.doc(s.id.toString()), json, SetOptions(merge: true));
      batch.delete(sessionsCol.doc(s.id.toString()));
    }

    await batch.commit();
  }

  Future<void> restoreDeletedUpcomingSessionsForClient(String clientId) async {
    if (clientId.trim().isEmpty) return;

    final deletedCol = _sessionsCollection(deleted: true);
    if (deletedCol == null) return;

    if (_deletedSessions.isEmpty) {
      try {
        final snap = await deletedCol.where('clientId', isEqualTo: clientId).get();
        _deletedSessions
          ..clear()
          ..addAll(
            snap.docs.map((doc) {
              final json = Map<String, dynamic>.from(doc.data());
              json['id'] = json['id'] ?? int.tryParse(doc.id) ?? 0;
              return ScheduleSession.fromJson(json);
            }),
          );
      } catch (_) {
        return;
      }
    }

    final restore = _deletedSessions.where((s) => s.clientId == clientId).toList();
    if (restore.isEmpty) return;

    final sessionsCol = _sessionsCollection();
    if (sessionsCol == null) return;

    final batch = firestoreDb.batch();
    final now = FieldValue.serverTimestamp();
    for (final s in restore) {
      final exists = _sessions.any((e) => e.id == s.id);
      if (!exists) _sessions.add(s);
      _deletedSessions.removeWhere((e) => e.id == s.id);

      final json = s.toJson();
      json['updatedAt'] = now;
      batch.set(sessionsCol.doc(s.id.toString()), json, SetOptions(merge: true));
      batch.delete(deletedCol.doc(s.id.toString()));
    }

    await batch.commit();
  }

  Future<void> loadFromStorage() async {
    final sessionsCol = _sessionsCollection();
    final deletedCol = _sessionsCollection(deleted: true);
    if (sessionsCol == null) {
      _sessions.clear();
      _deletedSessions.clear();
      return;
    }

    try {
      final snap = await sessionsCol.get();
      _sessions
        ..clear()
        ..addAll(
          snap.docs.map((doc) {
            final json = Map<String, dynamic>.from(doc.data());
            json['id'] = json['id'] ?? int.tryParse(doc.id) ?? 0;
            return ScheduleSession.fromJson(json);
          }),
        );
    } catch (_) {
      _sessions.clear();
    }

    if (deletedCol == null) return;
    try {
      final deletedSnap = await deletedCol.get();
      _deletedSessions
        ..clear()
        ..addAll(
          deletedSnap.docs.map((doc) {
            final json = Map<String, dynamic>.from(doc.data());
            json['id'] = json['id'] ?? int.tryParse(doc.id) ?? 0;
            return ScheduleSession.fromJson(json);
          }),
        );
    } catch (_) {
      _deletedSessions.clear();
    }
  }

  Future<void> _persistSession(ScheduleSession session) async {
    final ref = _sessionsCollection()?.doc(session.id.toString());
    if (ref == null) return;
    final json = session.toJson();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(json, SetOptions(merge: true));
  }
}
