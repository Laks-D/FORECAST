import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firestore_db.dart';

import '../../features/calendar/domain/entities/schedule_session.dart';
import '../../features/client/domain/entities/client.dart';
import '../storage/program_catalog_storage.dart';

/// Mirrors locally-stored app data into Firestore under the signed-in user.
///
/// Firestore layout:
/// - users/{uid}                           (profile + metadata)
/// - users/{uid}/settings/app              (nav modules + theme + notification prefs)
/// - users/{uid}/clients/{clientId}        (Client JSON)
/// - users/{uid}/sessions/{sessionId}      (ScheduleSession JSON)
class UserFirestoreSync {
  UserFirestoreSync._();

  static final UserFirestoreSync instance = UserFirestoreSync._();

  // Keep in sync with local datasource keys.
  static const String clientsPrefsKey = 'client_data_v1';
  static const String sessionsPrefsKey = 'sessions_data_v1';
  static const String navModulesPrefsKey = 'nav_modules_v1';
  static const String notificationPrefsKey = 'notification_prefs_v1';
  static const String signupProfilePrefsKey = 'signup_profile_data_v1';
  static const String adminProfilePrefsKey = 'admin_profile_data_v1';
  static const String appThemePrefsKey = 'app_theme_v1';

  Timer? _clientsDebounce;
  Timer? _sessionsDebounce;
  Timer? _settingsDebounce;
  Map<String, Object?>? _pendingSettings;

  String? _activeUid;
  int _clientsRetryCount = 0;
  int _sessionsRetryCount = 0;
  int _settingsRetryCount = 0;

  List<Client>? _lastClientsSnapshot;
  List<ScheduleSession>? _lastSessionsSnapshot;

  String? get _uid {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != _activeUid) {
      _activeUid = currentUid;
      _clientsDebounce?.cancel();
      _sessionsDebounce?.cancel();
      _settingsDebounce?.cancel();
      _pendingSettings = null;
      _clientsRetryCount = 0;
      _sessionsRetryCount = 0;
      _settingsRetryCount = 0;
      _lastClientsSnapshot = null;
      _lastSessionsSnapshot = null;
    }
    return currentUid;
  }

  Duration _backoff(int attempt) {
    final seconds = (2 << attempt).clamp(2, 30);
    return Duration(seconds: seconds);
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      firestoreDb.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) => _userDoc(uid)
      .collection('settings')
      .doc('app');

  CollectionReference<Map<String, dynamic>> _clientsCol(String uid) =>
      _userDoc(uid).collection('clients');

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) =>
      _userDoc(uid).collection('sessions');

  Object? _jsonSafe(Object? value) {
    if (value == null) return null;

    // Firestore types that are not JSON-encodable by dart:convert.
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is Blob) {
      return value.bytes;
    }
    if (value is DocumentReference) {
      return value.path;
    }

    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(
          k.toString(),
          _jsonSafe(v),
        ),
      );
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }

    // Primitives (String/num/bool) and other encodable types.
    return value;
  }

  /* ================= Pull (Firestore -> local) ================= */

  /// Pulls the signed-in user's data from Firestore into local SharedPreferences.
  ///
  /// Call this right after a user logs in and BEFORE creating blocs that
  /// immediately read from local storage.
  Future<void> pullAllToLocal({String? uidOverride}) async {
    final uid = uidOverride ?? _uid;
    if (uid == null) return;

    try {
      final settingsSnap = await _settingsDoc(uid).get();
      final settings = settingsSnap.data();
      if (settings != null) {
        final prefs = await SharedPreferences.getInstance();

        final navModules = settings['navModules'];
        if (navModules is Map<String, dynamic>) {
          await prefs.setString(navModulesPrefsKey, jsonEncode(navModules));
        }

        final notifPrefs = settings['notificationPrefs'];
        if (notifPrefs is Map<String, dynamic>) {
          // Keep notification preferences user-scoped so accounts don't leak.
          await prefs.setString('${notificationPrefsKey}_$uid', jsonEncode(notifPrefs));
        }

        final theme = settings['theme'];
        if (theme is Map<String, dynamic>) {
          await prefs.setString(appThemePrefsKey, jsonEncode(theme));
        }

        final signupProfile = settings['signupProfile'];
        if (signupProfile is Map<String, dynamic>) {
          await prefs.setString(signupProfilePrefsKey, jsonEncode(signupProfile));
        }

        final adminProfile = settings['adminProfile'];
        if (adminProfile is Map<String, dynamic>) {
          await prefs.setString(adminProfilePrefsKey, jsonEncode(adminProfile));
        }

        final programCatalog = settings['programCatalog'];
        if (programCatalog is List) {
          await ProgramCatalogStorage.overwriteFromJsonList(programCatalog, uid: uid);
        }
      }
    } catch (e) {
      debugPrint('UserFirestoreSync.pullAllToLocal: settings pull failed: $e');
    }

    try {
      final clientSnaps = await _clientsCol(uid).get();
      final clients = clientSnaps.docs
          .map((d) => _jsonSafe(d.data()))
          .whereType<Map<String, dynamic>>()
          .where((m) => m.isNotEmpty)
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clientsPrefsKey, jsonEncode(clients));
    } catch (e) {
      debugPrint('UserFirestoreSync.pullAllToLocal: clients pull failed: $e');
    }

    try {
      final sessionSnaps = await _sessionsCol(uid).get();
      final sessions = sessionSnaps.docs
          .map((d) => _jsonSafe(d.data()))
          .whereType<Map<String, dynamic>>()
          .where((m) => m.isNotEmpty)
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionsPrefsKey, jsonEncode(sessions));
    } catch (e) {
      debugPrint('UserFirestoreSync.pullAllToLocal: sessions pull failed: $e');
    }
  }

  /* ================= Push (local -> Firestore) ================= */

  /// Immediately patches the user's settings doc (no debounce).
  /// Use this for critical writes that must not be dropped on logout.
  Future<void> patchSettingsNow(Map<String, Object?> patch) async {
    final uid = _uid;
    if (uid == null) return;
    if (patch.isEmpty) return;

    // Merge with any pending debounced payload and cancel the timer.
    _settingsDebounce?.cancel();
    final merged = {...?_pendingSettings, ...patch};
    _pendingSettings = null;

    try {
      await _settingsDoc(uid).set(
        {
          ...merged,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _settingsRetryCount = 0;
      if (kDebugMode) {
        debugPrint('UserFirestoreSync: patched settings NOW -> users/$uid/settings/app');
      }
    } catch (e) {
      debugPrint('UserFirestoreSync.patchSettingsNow failed: $e');
    }
  }

  Future<void> upsertUserProfile({
    String? fullName,
    String? middleName,
    String? email,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _userDoc(uid).set(
        {
          'uid': uid,
          'fullName': fullName,
          'middleName': middleName,
          'email': email,
          'phone': phone,
          'gender': gender,
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        }..removeWhere((_, v) => v == null),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('UserFirestoreSync.upsertUserProfile failed: $e');
    }
  }

  /// Debounced push of clients collection.
  void scheduleClientsSync(List<Client> clients) {
    _lastClientsSnapshot = clients;
    _clientsDebounce?.cancel();
    _clientsDebounce = Timer(const Duration(milliseconds: 800), () async {
      await _pushClients(clients);
    });
  }

  Future<void> _pushClients(List<Client> clients) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final batch = firestoreDb.batch();
      final col = _clientsCol(uid);
      for (final c in clients) {
        batch.set(
          col.doc(c.id),
          {
            ...c.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      _clientsRetryCount = 0;
      if (kDebugMode) {
        debugPrint('UserFirestoreSync: synced ${clients.length} clients -> users/$uid/clients');
      }
    } catch (e) {
      debugPrint('UserFirestoreSync._pushClients failed: $e');

      // Retry on transient offline/unavailable failures.
      final shouldRetry = e is FirebaseException && e.code == 'unavailable';
      if (!shouldRetry) return;

      final snapshot = _lastClientsSnapshot;
      if (snapshot == null || snapshot.isEmpty) return;

      final attempt = _clientsRetryCount.clamp(0, 4);
      _clientsRetryCount = (_clientsRetryCount + 1).clamp(0, 6);
      Timer(_backoff(attempt), () async {
        await _pushClients(snapshot);
      });
    }
  }

  /// Debounced push of sessions collection.
  void scheduleSessionsSync(List<ScheduleSession> sessions) {
    _lastSessionsSnapshot = sessions;
    _sessionsDebounce?.cancel();
    _sessionsDebounce = Timer(const Duration(milliseconds: 800), () async {
      await _pushSessions(sessions);
    });
  }

  Future<void> _pushSessions(List<ScheduleSession> sessions) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final batch = firestoreDb.batch();
      final col = _sessionsCol(uid);
      for (final s in sessions) {
        batch.set(
          col.doc(s.id.toString()),
          {
            ...s.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      _sessionsRetryCount = 0;
      if (kDebugMode) {
        debugPrint('UserFirestoreSync: synced ${sessions.length} sessions -> users/$uid/sessions');
      }
    } catch (e) {
      debugPrint('UserFirestoreSync._pushSessions failed: $e');

      final shouldRetry = e is FirebaseException && e.code == 'unavailable';
      if (!shouldRetry) return;

      final snapshot = _lastSessionsSnapshot;
      if (snapshot == null || snapshot.isEmpty) return;

      final attempt = _sessionsRetryCount.clamp(0, 4);
      _sessionsRetryCount = (_sessionsRetryCount + 1).clamp(0, 6);
      Timer(_backoff(attempt), () async {
        await _pushSessions(snapshot);
      });
    }
  }

  /// Debounced patch of user settings.
  void scheduleSettingsPatch(Map<String, Object?> patch) {
    _pendingSettings = {...?_pendingSettings, ...patch};

    _settingsDebounce?.cancel();
    _settingsDebounce = Timer(const Duration(milliseconds: 500), () async {
      final uid = _uid;
      final payload = _pendingSettings;
      _pendingSettings = null;
      if (uid == null) return;
      if (payload == null || payload.isEmpty) return;

      try {
        await _settingsDoc(uid).set(
          {
            ...payload,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        _settingsRetryCount = 0;
        if (kDebugMode) {
          debugPrint('UserFirestoreSync: patched settings -> users/$uid/settings/app');
        }
      } catch (e) {
        debugPrint('UserFirestoreSync.scheduleSettingsPatch failed: $e');

        final shouldRetry = e is FirebaseException && e.code == 'unavailable';
        if (!shouldRetry) return;

        final attempt = _settingsRetryCount.clamp(0, 4);
        _settingsRetryCount = (_settingsRetryCount + 1).clamp(0, 6);
        _pendingSettings = {...payload};
        Timer(_backoff(attempt), () {
          scheduleSettingsPatch(const {});
        });
      }
    });
  }

  /* ================= Convenience (save local copies into settings doc) ================= */

  /// Optional: persist the same JSON blobs we keep locally into Firestore so you
  /// can inspect them in Firebase Console easily.
  Future<void> mirrorLocalSettingsBlobs() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      Map<String, dynamic>? readJson(String key) {
        final raw = prefs.getString(key);
        if (raw == null || raw.trim().isEmpty) return null;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
        return null;
      }

      scheduleSettingsPatch({
        if (readJson(navModulesPrefsKey) != null)
          'navModules': readJson(navModulesPrefsKey),
        if (readJson(notificationPrefsKey) != null)
          'notificationPrefs': readJson(notificationPrefsKey),
        if (readJson(appThemePrefsKey) != null) 'theme': readJson(appThemePrefsKey),
        if (readJson(signupProfilePrefsKey) != null)
          'signupProfile': readJson(signupProfilePrefsKey),
        if (readJson(adminProfilePrefsKey) != null)
          'adminProfile': readJson(adminProfilePrefsKey),
      });
    } catch (e) {
      debugPrint('UserFirestoreSync.mirrorLocalSettingsBlobs failed: $e');
    }
  }
}
