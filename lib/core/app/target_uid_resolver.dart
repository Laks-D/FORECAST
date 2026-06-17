import 'package:firebase_auth/firebase_auth.dart';

import 'app_mode.dart';
import 'student_enrollment_resolver.dart';

/// Resolves the Firestore "owner" uid whose sub-collections the app should
/// read/write right now.
///
/// - Tutor (admin) mode  → the signed-in user's own uid.
/// - Student (client) mode → the *tutor's* uid the student is enrolled with
///   (data lives under the tutor's user document).
///
/// All new data-layer repositories take a `targetUid` callback so they can be
/// unit-tested without Firebase/Auth. Production wiring passes
/// [defaultTargetUid]; tests pass a stub.
typedef TargetUidProvider = Future<String?> Function();

Future<String?> defaultTargetUid() async {
  if (AppModeConfig.isClient) {
    return StudentEnrollmentResolver.getTargetUid();
  }
  return FirebaseAuth.instance.currentUser?.uid;
}
