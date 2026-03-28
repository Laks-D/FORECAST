import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firestore_db.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handling can be extended later (e.g., analytics, deep links).
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> init() async {
    if (_initialized) return;

    // Hook background handler for supported platforms.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Permissions (required on iOS/web; Android is a no-op).
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Ignore permission errors; token retrieval will fail if not allowed.
    }

    // Foreground messages: show a local notification on mobile.
    FirebaseMessaging.onMessage.listen((message) async {
      if (kIsWeb) return;
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title == null || body == null) return;
      await NotificationService.instance.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body,
      );
    });

    // (Re)register token whenever the user signs in.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(_registerTokenForUser(uid: user.uid));
    });

    // Keep token fresh.
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      unawaited(_saveToken(uid: uid, token: token));
    });

    _initialized = true;
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }

  Future<void> _registerTokenForUser({required String uid}) async {
    final token = await _getFcmToken();
    if (token == null || token.trim().isEmpty) return;
    await _saveToken(uid: uid, token: token);
  }

  Future<String?> _getFcmToken() async {
    if (!kIsWeb) {
      return FirebaseMessaging.instance.getToken();
    }

    // Web requires a VAPID key. Provide it via:
    //   flutter run -d chrome --dart-define=FIREBASE_VAPID_KEY=YOUR_KEY
    const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
    if (vapidKey.trim().isEmpty) {
      return null;
    }

    return FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
  }

  Future<void> _saveToken({required String uid, required String token}) async {
    await firestoreDb
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .set(
      {
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
