import 'package:firebase_auth/firebase_auth.dart';
import '../firebase/firestore_db.dart';
import 'app_mode.dart';

class StudentEnrollmentResolver {
  /// Returns the target UID for fetching data.
  /// If the user is a Tutor (or non-client), returns their own UID.
  /// If the user is a Client, fetches their primary enrolled Tutor's UID.
  static Future<String?> getTargetUid() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.trim().isEmpty) return null;

    if (AppModeConfig.isClient) {
      final snap = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('enrollment')
          .limit(1)
          .get();
          
      if (snap.docs.isNotEmpty) {
        final tutorId = snap.docs.first.data()['tutorId'] as String?;
        if (tutorId != null && tutorId.trim().isNotEmpty) {
          return tutorId;
        }
      }

      // Fallback: If no enrollment exists, search for manually created clients by email or phone
      try {
        final email = user?.email;
        if (email != null && email.isNotEmpty) {
          final orphanSnap = await firestoreDb
              .collectionGroup('clients')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (orphanSnap.docs.isNotEmpty) {
            final clientDoc = orphanSnap.docs.first;
            final tutorId = clientDoc.reference.parent.parent?.id;

            if (tutorId != null) {
              await _enroll(uid, tutorId);
              return tutorId;
            }
          }
        }

        final phone = user?.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          final orphanSnap = await firestoreDb
              .collectionGroup('clients')
              .where('primaryContact', isEqualTo: phone)
              .limit(1)
              .get();

          if (orphanSnap.docs.isNotEmpty) {
            final clientDoc = orphanSnap.docs.first;
            final tutorId = clientDoc.reference.parent.parent?.id;

            if (tutorId != null) {
              await _enroll(uid, tutorId);
              return tutorId;
            }
          }
        }
      } catch (_) {
        // If the collectionGroup query fails (e.g. requires index), fail gracefully
      }
    }
    
    // Fallback or Admin mode
    return uid;
  }

  static Future<void> _enroll(String uid, String tutorId) async {
    await firestoreDb
        .collection('users')
        .doc(uid)
        .collection('enrollment')
        .doc(tutorId)
        .set({
      'tutorId': tutorId,
      'tutorName': 'Tutor',
      'status': 'enrolled',
    });
  }
}
