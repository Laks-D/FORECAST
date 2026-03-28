import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firestore_db.dart';
import '../services/notification_service.dart';

/// Enable dev-mode behavior (skip login UI) with:
/// `flutter run -d chrome --dart-define=SKIP_AUTH=true`
const bool kSkipAuth = bool.fromEnvironment('SKIP_AUTH', defaultValue: false);

Future<void> runDevBootstrap() async {
  if (!kSkipAuth) return;

  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('DEV bootstrap: anonymous sign-in failed: $e');
    return;
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    final userRef = firestoreDb.collection('users').doc(uid);

    await userRef.set(
      {
        'uid': uid,
        'isAnonymous': true,
        'devMode': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      },
      SetOptions(merge: true),
    );

    // Read-back (helps confirm rules/connectivity in logs).
    final snap = await userRef.get();
    debugPrint('DEV bootstrap: users/$uid exists=${snap.exists}');
  } catch (e) {
    debugPrint('DEV bootstrap: Firestore user-doc write/read failed: $e');
  }

  // Local notifications aren't supported on web. This is a quick smoke check for
  // Android/iOS builds.
  try {
    await NotificationService.instance.show(
      id: 999001,
      title: 'GeneralApp (dev)',
      body: 'Notifications are working (local).',
      payload: 'dev_smoke',
    );
  } catch (e) {
    debugPrint('DEV bootstrap: local notification failed: $e');
  }
}
