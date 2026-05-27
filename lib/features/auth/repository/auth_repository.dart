import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firebase/firestore_db.dart';
import '../../../core/storage/admin_profile_storage.dart';

/// All Firebase Auth + Firestore calls for the auth flow live here.
///
/// Keeping them in one place makes it easy to trace exactly what happens
/// during signup and login without hunting through BLoC handlers.
class AuthRepository {
  AuthRepository._();
  static final instance = AuthRepository._();

  // ── Sign-up ──────────────────────────────────────────────────────────────

  /// Creates a new Firebase Auth account, writes the user profile + role to
  /// Firestore, then **signs the user out**.
  ///
  /// The caller must set [SignupController.isSignupInProgress] = true before
  /// calling and may rely on LandingScreen blocking dashboard routing while
  /// that flag is set.
  ///
  /// Throws [FirebaseAuthException] or [Exception] on failure.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String profession,
    required String role, // 'tutor' | 'client'
  }) async {
    // 1. Create Firebase Auth account.
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    // 2. Write display name to Firebase Auth.
    await user.updateDisplayName(fullName.trim());

    // 3. Write full profile + role to Firestore while authenticated.
    await firestoreDb.collection('users').doc(user.uid).set(
      {
        'fullName': fullName.trim(),
        'profession': profession.trim(),
        'email': email.trim(),
        'roles': [role],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 4. Create a self-profile in the `clients` subcollection ONLY for students.
    // This allows the student app to have a linked profile to read and display on the profile page.
    final isClientMode = role.trim().toLowerCase() == 'client' || role.trim().toLowerCase() == 'student';
    if (isClientMode) {
      final nowIso = DateTime.now().toIso8601String();
      await firestoreDb
          .collection('users')
          .doc(user.uid)
          .collection('clients')
          .doc(user.uid)
          .set(
        {
          'id': user.uid,
          'firebaseUid': user.uid,
          'name': fullName.trim(),
          'primaryContact': '',
          'email': email.trim(),
          'status': 'Active',
          'timeline': [
            {
              'id': 'creation_${DateTime.now().millisecondsSinceEpoch}',
              'type': 'Profile created',
              'createdAt': nowIso,
            }
          ],
        },
        SetOptions(merge: true),
      );
    }
    // 5. Save to AdminProfileStorage so Tutor dashboard has name/email on first login.
    await AdminProfileStorage.save(
      userName: fullName.trim(),
      userEmail: email.trim(),
    );

    // 6. Sign out — user must explicitly log in after signup.
    await FirebaseAuth.instance.signOut();
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  /// Signs in with email/password and validates that the account has the
  /// [expectedRole].  Signs out and throws [FirebaseAuthException] with code
  /// [ROLE_MISMATCH] if the role does not match.
  Future<User> signIn({
    required String email,
    required String password,
    required String expectedRole, // 'tutor' | 'client'
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await _assertRole(user.uid, expectedRole);
    // Update last-login timestamp.
    firestoreDb.collection('users').doc(user.uid).set(
      {'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    ).ignore();
    return user;
  }

  /// Signs in with Google and validates the role. If the Google account does
  /// not exist yet in Firestore (new user), treats it as a signup and writes
  /// the role, then signs out and returns null so the caller knows to show
  /// a success message.
  ///
  /// Returns the signed-in [User] on successful login.
  /// Throws [FirebaseAuthException] on mismatch / failure.
  Future<User?> signInWithGoogle({required String expectedRole}) async {
    throw UnimplementedError('Google sign-in not wired in this version');
  }

  // ── Sign-out ──────────────────────────────────────────────────────────────

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  // ── Role helpers ─────────────────────────────────────────────────────────

  Future<void> _assertRole(String uid, String expectedRole) async {
    final snap = await firestoreDb.collection('users').doc(uid).get();
    final raw = snap.data()?['roles'];
    List<String> roles = [];
    if (raw is List) roles = raw.cast<String>();

    // Legacy: check sub-collections if roles array is empty.
    if (roles.isEmpty) {
      roles = await _inferRolesFromSubcollections(uid);
      if (roles.isNotEmpty) {
        firestoreDb.collection('users').doc(uid).set(
          {'roles': roles},
          SetOptions(merge: true),
        ).ignore();
      }
    }

    if (roles.isEmpty) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'Account has no role assigned. Please complete sign-up.',
      );
    }

    final wantsTutor = expectedRole == 'tutor';
    final hasTutor = roles.contains('tutor');
    final hasClient = roles.contains('client') || roles.contains('student');

    if (wantsTutor && !hasTutor) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message:
            'This is a Student account. Please use the Student login.',
      );
    }
    if (!wantsTutor && !hasClient) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'This is a Tutor account. Please use the Tutor login.',
      );
    }
  }

  Future<List<String>> _inferRolesFromSubcollections(String uid) async {
    bool isTutor = false;
    bool isClient = false;
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('clients')
          .limit(1)
          .get();
      isTutor = s.docs.isNotEmpty;
    } catch (_) {}
    try {
      final s = await firestoreDb
          .collection('organizations')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (s.docs.isNotEmpty) isTutor = true;
    } catch (_) {}
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('enrollment')
          .limit(1)
          .get();
      isClient = s.docs.isNotEmpty;
    } catch (_) {}
    return [if (isTutor) 'tutor', if (isClient) 'client'];
  }

  // ── Role fetch (used by LandingScreen) ───────────────────────────────────

  Future<List<String>> fetchRoles(String uid) async {
    try {
      final snap = await firestoreDb.collection('users').doc(uid).get();
      final raw = snap.data()?['roles'];
      if (raw is List && raw.isNotEmpty) return raw.cast<String>();
    } catch (_) {}
    final inferred = await _inferRolesFromSubcollections(uid);
    if (inferred.isNotEmpty) {
      firestoreDb.collection('users').doc(uid).set(
        {'roles': inferred},
        SetOptions(merge: true),
      ).ignore();
    }
    return inferred;
  }
}
