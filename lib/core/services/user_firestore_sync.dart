
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firestore_db.dart';
import '../../features/client/domain/entities/client.dart';
import '../../features/calendar/domain/entities/schedule_session.dart';

/// Best-effort mirroring of local, per-user data into Firestore.
///
/// This app primarily persists locally (SharedPreferences). Firestore syncing is
/// used so data survives logout/login and can sync across devices.
///
/// Schema reference: docs/FIRESTORE_SCHEMA.md
class UserFirestoreSync {
	UserFirestoreSync._();

	static final UserFirestoreSync instance = UserFirestoreSync._();

	Timer? _settingsDebounce;
	final Map<String, dynamic> _pendingSettingsPatch = <String, dynamic>{};

	Timer? _clientsDebounce;
	List<Client> _pendingClients = const <Client>[];

	Timer? _sessionsDebounce;
	List<ScheduleSession> _pendingSessions = const <ScheduleSession>[];

	bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

	String? get _uid => FirebaseAuth.instance.currentUser?.uid;

	DocumentReference<Map<String, dynamic>>? get _userDoc {
		final uid = _uid;
		if (uid == null || uid.trim().isEmpty) return null;
		return firestoreDb.collection('users').doc(uid);
	}

	DocumentReference<Map<String, dynamic>>? get _settingsDoc {
		final userDoc = _userDoc;
		if (userDoc == null) return null;
		return userDoc.collection('settings').doc('app');
	}

	/// Merge patch into `users/{uid}/settings/app` with debouncing.
	void scheduleSettingsPatch(Map<String, dynamic> patch, {Duration debounce = const Duration(milliseconds: 900)}) {
		if (patch.isEmpty) return;
		_pendingSettingsPatch.addAll(patch);

		_settingsDebounce?.cancel();
		_settingsDebounce = Timer(debounce, () {
			final payload = Map<String, dynamic>.from(_pendingSettingsPatch);
			_pendingSettingsPatch.clear();
			unawaited(patchSettingsNow(payload));
		});
	}

	/// Immediately patch `users/{uid}/settings/app`.
	Future<void> patchSettingsNow(Map<String, dynamic> patch) async {
		final ref = _settingsDoc;
		if (ref == null || patch.isEmpty) return;

		final payload = <String, dynamic>{
			...patch,
			'updatedAt': FieldValue.serverTimestamp(),
		};

		try {
			await ref.set(payload, SetOptions(merge: true));
		} catch (e) {
			if (kDebugMode) {
				debugPrint('UserFirestoreSync.patchSettingsNow failed: $e');
			}
		}
	}

	/// Upsert top-level user profile data at `users/{uid}`.
	Future<void> upsertUserProfile({
		String? fullName,
		String? handle,
		String? middleName,
		String? email,
		String? phone,
		String? gender,
		DateTime? dateOfBirth,
	}) async {
		final ref = _userDoc;
		if (ref == null) return;

		final payload = <String, dynamic>{
			'updatedAt': FieldValue.serverTimestamp(),
			'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
		};

		// Only store fields if provided (avoid overwriting with nulls).
		if (fullName != null) payload['fullName'] = fullName;
		if (handle != null) payload['username'] = handle;
		if (middleName != null) payload['middleName'] = middleName;
		if (email != null) payload['email'] = email;
		if (phone != null) payload['phone'] = phone;
		if (gender != null) payload['gender'] = gender;
		if (dateOfBirth != null) payload['dateOfBirth'] = dateOfBirth.toIso8601String();

		try {
			await ref.set(payload, SetOptions(merge: true));
		} catch (e) {
			if (kDebugMode) {
				debugPrint('UserFirestoreSync.upsertUserProfile failed: $e');
			}
		}
	}

	/// Debounced upsert of each client into `users/{uid}/clients/{clientId}`.
	void scheduleClientsSync(List<Client> clients, {Duration debounce = const Duration(milliseconds: 1200)}) {
		_pendingClients = clients;
		_clientsDebounce?.cancel();
		_clientsDebounce = Timer(debounce, () {
			final copy = List<Client>.from(_pendingClients);
			_pendingClients = const <Client>[];
			unawaited(_syncClientsNow(copy));
		});
	}

	Future<void> _syncClientsNow(List<Client> clients) async {
		final userDoc = _userDoc;
		if (userDoc == null) return;
		if (clients.isEmpty) return;

		try {
			final batch = firestoreDb.batch();
			final now = FieldValue.serverTimestamp();
			for (final c in clients) {
				final ref = userDoc.collection('clients').doc(c.id);
				final json = c.toJson();
				json['updatedAt'] = now;
				batch.set(ref, json, SetOptions(merge: true));
			}
			await batch.commit();
		} catch (e) {
			if (kDebugMode) {
				debugPrint('UserFirestoreSync._syncClientsNow failed: $e');
			}
		}
	}

	/// Debounced upsert of each session into `users/{uid}/sessions/{sessionId}`.
	void scheduleSessionsSync(List<ScheduleSession> sessions, {Duration debounce = const Duration(milliseconds: 1200)}) {
		_pendingSessions = sessions;
		_sessionsDebounce?.cancel();
		_sessionsDebounce = Timer(debounce, () {
			final copy = List<ScheduleSession>.from(_pendingSessions);
			_pendingSessions = const <ScheduleSession>[];
			unawaited(_syncSessionsNow(copy));
		});
	}

	Future<void> _syncSessionsNow(List<ScheduleSession> sessions) async {
		final userDoc = _userDoc;
		if (userDoc == null) return;
		if (sessions.isEmpty) return;

		try {
			final batch = firestoreDb.batch();
			final now = FieldValue.serverTimestamp();
			for (final s in sessions) {
				final ref = userDoc.collection('sessions').doc(s.id.toString());
				final json = s.toJson();
				json['updatedAt'] = now;
				batch.set(ref, json, SetOptions(merge: true));
			}
			await batch.commit();
		} catch (e) {
			if (kDebugMode) {
				debugPrint('UserFirestoreSync._syncSessionsNow failed: $e');
			}
		}
	}

	Future<void> dispose() async {
		_settingsDebounce?.cancel();
		_clientsDebounce?.cancel();
		_sessionsDebounce?.cancel();
	}
}

