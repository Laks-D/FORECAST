
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firestore_db.dart';

/// Firestore-backed user data access.
///
/// Schema reference: docs/FIRESTORE_SCHEMA.md
class UserFirestoreSync {
	UserFirestoreSync._();

	static final UserFirestoreSync instance = UserFirestoreSync._();

	Timer? _settingsDebounce;
	final Map<String, dynamic> _pendingSettingsPatch = <String, dynamic>{};

	bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

	String? get _uid => FirebaseAuth.instance.currentUser?.uid;

	DocumentReference<Map<String, dynamic>>? get userDoc {
		final uid = _uid;
		if (uid == null || uid.trim().isEmpty) return null;
		return firestoreDb.collection('users').doc(uid);
	}

	DocumentReference<Map<String, dynamic>>? get settingsDoc {
		final doc = userDoc;
		if (doc == null) return null;
		return doc.collection('settings').doc('app');
	}

	Future<Map<String, dynamic>?> loadSettings() async {
		final ref = settingsDoc;
		if (ref == null) return null;
		try {
			final snap = await ref.get();
			return snap.data();
		} catch (_) {
			return null;
		}
	}

	/// Merge patch into `users/{uid}/settings/app` with debouncing.
	void scheduleSettingsPatch(
		Map<String, dynamic> patch, {
		Duration debounce = const Duration(milliseconds: 900),
	}) {
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
		final ref = settingsDoc;
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
		final ref = userDoc;
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
		if (dateOfBirth != null) {
			payload['dateOfBirth'] = dateOfBirth.toIso8601String();
		}

		try {
			await ref.set(payload, SetOptions(merge: true));
		} catch (e) {
			if (kDebugMode) {
				debugPrint('UserFirestoreSync.upsertUserProfile failed: $e');
			}
		}
	}

	Future<void> dispose() async {
		_settingsDebounce?.cancel();
	}
}

