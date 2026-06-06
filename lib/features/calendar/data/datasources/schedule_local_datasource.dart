import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/schedule_session.dart';
import '../../../../core/app/app_mode.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/firebase/firestore_db.dart';

class ScheduleLocalDataSource {
  final List<ScheduleSession> _sessions = [];
  final List<ScheduleSession> _deletedSessions = [];

  // Tracked subscriptions for the student session watcher so we can cancel
  // them cleanly when enrollment changes (prevents stream leaks).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _enrollmentSub;
  final List<StreamSubscription<List<ScheduleSession>>> _tutorSubs = [];

  CollectionReference<Map<String, dynamic>>? _sessionsCollection(
      {bool deleted = false}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return null;
    final userDoc = firestoreDb.collection('users').doc(uid);
    return userDoc.collection(deleted ? 'deleted_sessions' : 'sessions');
  }

  Stream<List<ScheduleSession>> watchSessions() {
    // Student mode: stream sessions from every enrolled tutor's collection
    // where clientId matches the current student's internal client doc id.
    if (AppModeConfig.isClient) {
      return _watchClientSessions();
    }

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

  // ---------------------------------------------------------------------------
  // Fix B: _watchSessionsForTutor — adds email/phone fallback when firebaseUid
  //        is not present on the client record (manually-created students).
  //        Also auto-patches firebaseUid on first successful email/phone match
  //        so future lookups always use the fast path.
  // ---------------------------------------------------------------------------
  Stream<List<ScheduleSession>> _watchSessionsForTutor(
      String tutorId, String uid) {
    // We use snapshots() so that if the Tutor's app writes the client profile
    // *after* the enrollment document triggers this stream (race condition),
    // we still pick it up instantly.
    return firestoreDb
        .collection('users')
        .doc(tutorId)
        .collection('clients')
        .where('firebaseUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .asyncExpand((uidSnap) {
      if (uidSnap.docs.isNotEmpty) {
        final clientId = uidSnap.docs.first.id;
        return _sessionsStreamForClient(tutorId, clientId);
      } else {
        // If fast-path fails, fallback to checking email/phone via a one-off
        // get() to see if we need to auto-patch. If we do patch, the
        // snapshot listener above will trigger again natively!
        return Stream.fromFuture(_attemptAutoPatch(tutorId, uid)).asyncExpand((_) {
          return Stream.value(const <ScheduleSession>[]);
        });
      }
    });
  }

  Future<void> _attemptAutoPatch(String tutorId, String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        final emailSnap = await firestoreDb
            .collection('users')
            .doc(tutorId)
            .collection('clients')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailSnap.docs.isNotEmpty) {
           unawaited(emailSnap.docs.first.reference.update({'firebaseUid': uid}));
           return;
        }
      }

      final phone = user?.phoneNumber?.trim();
      if (phone != null && phone.isNotEmpty) {
        final phoneSnap = await firestoreDb
            .collection('users')
            .doc(tutorId)
            .collection('clients')
            .where('primaryContact', isEqualTo: phone)
            .limit(1)
            .get();

        if (phoneSnap.docs.isNotEmpty) {
           unawaited(phoneSnap.docs.first.reference.update({'firebaseUid': uid}));
           return;
        }
      }
    } catch (_) {}
  }

  /// Streams sessions from a tutor's collection filtered by internal clientId.
  Stream<List<ScheduleSession>> _sessionsStreamForClient(
      String tutorId, String clientId) {
    return firestoreDb
        .collection('users')
        .doc(tutorId)
        .collection('sessions')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final json = Map<String, dynamic>.from(doc.data());
              json['id'] = json['id'] ?? int.tryParse(doc.id) ?? 0;
              return ScheduleSession.fromJson(json);
            }).toList(growable: false));
  }

  // ---------------------------------------------------------------------------
  // Fix E: _watchClientSessions — replace the leaky asyncExpand+anonymous
  //        StreamController pattern with explicit subscription tracking.
  //        Old per-tutor subs are cancelled before new ones are created,
  //        preventing double-emissions and memory leaks.
  // ---------------------------------------------------------------------------
  Stream<List<ScheduleSession>> _watchClientSessions() async* {
    // Fix 9/edge-case 9: wait for auth to fully initialize on cold start.
    final initialUser = await FirebaseAuth.instance.authStateChanges().first;
    final uid = initialUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      yield const <ScheduleSession>[];
      return;
    }

    final controller = StreamController<List<ScheduleSession>>();

    _enrollmentSub = firestoreDb
        .collection('users')
        .doc(uid)
        .collection('enrollment')
        .where('status', isEqualTo: 'enrolled')
        .snapshots()
        .listen(
      (snap) {
        // Cancel all per-tutor subs from the previous enrollment snapshot.
        for (final s in _tutorSubs) {
          s.cancel();
        }
        _tutorSubs.clear();

        final tutorIds = snap.docs.map((d) => d.id).toList();
        if (AppModeConfig.isDualRole && !tutorIds.contains(uid)) {
          tutorIds.add(uid!);
        }

        if (tutorIds.isEmpty) {
          if (!controller.isClosed) controller.add(const []);
          return;
        }

        final latest = List<List<ScheduleSession>>.filled(
            tutorIds.length, const [],
            growable: false);

        for (var i = 0; i < tutorIds.length; i++) {
          final idx = i;
          final sub = _watchSessionsForTutor(tutorIds[idx], uid).listen(
            (items) {
              latest[idx] = items;
              if (!controller.isClosed) {
                controller.add(
                    latest.expand((l) => l).toList(growable: false));
              }
            },
            onError: (e) {
              // Even if a tutor stream fails, we must update the controller
              // so the UI knows we finished attempting to load this stream.
              // Otherwise, the SessionsCubit stays in isLoading = true forever.
              latest[idx] = const [];
              if (!controller.isClosed) {
                controller.add(
                    latest.expand((l) => l).toList(growable: false));
              }
            },
          );
          _tutorSubs.add(sub);
        }
      },
      onError: (_) {
        if (!controller.isClosed) controller.add(const []);
      },
    );

    controller.onCancel = () {
      _enrollmentSub?.cancel();
      _enrollmentSub = null;
      for (final s in _tutorSubs) {
        s.cancel();
      }
      _tutorSubs.clear();
    };

    yield* controller.stream;
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
      final derived =
          AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
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
      batch.set(deletedCol.doc(s.id.toString()), json,
          SetOptions(merge: true));
      batch.delete(sessionsCol.doc(s.id.toString()));
    }

    await batch.commit();
  }

  Future<void> restoreDeletedUpcomingSessionsForClient(
      String clientId) async {
    if (clientId.trim().isEmpty) return;

    final deletedCol = _sessionsCollection(deleted: true);
    if (deletedCol == null) return;

    if (_deletedSessions.isEmpty) {
      try {
        final snap =
            await deletedCol.where('clientId', isEqualTo: clientId).get();
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

    final restore =
        _deletedSessions.where((s) => s.clientId == clientId).toList();
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
      batch.set(sessionsCol.doc(s.id.toString()), json,
          SetOptions(merge: true));
      batch.delete(deletedCol.doc(s.id.toString()));
    }

    await batch.commit();
  }

  Future<void> loadFromStorage() async {
    // Wait for Firebase Auth to complete its initial sync.
    // This prevents a race condition on cold startup where currentUser
    // is temporarily null.
    await FirebaseAuth.instance.authStateChanges().first;

    // Client (student) mode: sessions come entirely from the real-time
    // _watchClientSessions() stream. Skip the local load to avoid reading
    // from the wrong (student's own empty) sessions collection.
    if (AppModeConfig.isClient) return;

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

  /// Cancel all active streaming subscriptions. Call this when the datasource
  /// is no longer needed (e.g., from SessionsCubit.close()).
  Future<void> dispose() async {
    await _enrollmentSub?.cancel();
    _enrollmentSub = null;
    for (final s in _tutorSubs) {
      await s.cancel();
    }
    _tutorSubs.clear();
  }

  Future<void> _persistSession(ScheduleSession session) async {
    final ref = _sessionsCollection()?.doc(session.id.toString());
    if (ref == null) return;
    final json = session.toJson();
    json['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(json, SetOptions(merge: true));
  }
}
