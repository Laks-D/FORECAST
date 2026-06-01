import 'package:firebase_auth/firebase_auth.dart';
import '../firebase/firestore_db.dart';
import 'app_mode.dart';

class StudentEnrollmentResolver {
  // ---------------------------------------------------------------------------
  // Fix C: In-memory cache with per-UID validation.
  // Eliminates the Firestore round-trip on every data operation.
  // Cache is invalidated explicitly on sign-out (via invalidateCache()) and
  // implicitly when the UID changes.
  // ---------------------------------------------------------------------------
  static String? _cachedTutorUid;
  static String? _cachedForUid;

  /// Clears the cached tutor-uid. Must be called on sign-out so that the next
  /// user session always re-fetches a fresh enrollment record.
  static void invalidateCache() {
    _cachedTutorUid = null;
    _cachedForUid = null;
  }

  /// Returns the target UID for fetching data.
  /// If the user is a Tutor (or non-client), returns their own UID.
  /// If the user is a Client, fetches their primary enrolled Tutor's UID.
  static Future<String?> getTargetUid() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.trim().isEmpty) return null;

    if (!AppModeConfig.isClient) return uid;

    // --- Cache hit ---
    if (_cachedForUid == uid && _cachedTutorUid != null) {
      return _cachedTutorUid;
    }

    // --- Primary: enrollment sub-collection ---
    final snap = await firestoreDb
        .collection('users')
        .doc(uid)
        .collection('enrollment')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final tutorId = snap.docs.first.data()['tutorId'] as String?;
      if (tutorId != null && tutorId.trim().isNotEmpty) {
        _cachedForUid = uid;
        _cachedTutorUid = tutorId;
        return tutorId;
      }
    }

    // --- Fallback: collectionGroup query by email then phone ---
    // Used for students who were manually added by a tutor (no QR flow).
    try {
      final email = user?.email?.trim().toLowerCase();
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
            _cachedForUid = uid;
            _cachedTutorUid = tutorId;
            return tutorId;
          }
        }
      }

      final phone = user?.phoneNumber?.trim();
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
            _cachedForUid = uid;
            _cachedTutorUid = tutorId;
            return tutorId;
          }
        }
      }
    } catch (_) {
      // If the collectionGroup query fails (e.g. index not built), fail gracefully.
    }

    // Fallback or Admin mode — return own UID.
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
