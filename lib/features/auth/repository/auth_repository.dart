import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/auth/google_auth.dart';
import '../../../core/firebase/firestore_db.dart';
import '../../../core/storage/admin_profile_storage.dart';
import '../data/username_repository.dart';
import '../../audit/audit_service.dart';

/// All Firebase Auth + Firestore calls for the auth flow.
///
/// Role values: 'tutor' | 'client' | 'both'
/// Stored in Firestore as roles: ['tutor'] | ['client'] | ['tutor','client']
class AuthRepository {
  AuthRepository._();
  static final instance = AuthRepository._();

  // ── Sign-up ──────────────────────────────────────────────────────────────

  /// Creates a new Firebase Auth account, writes profile + role(s) to
  /// Firestore, then signs the user out.
  ///
  /// [role] is 'tutor', 'client', or 'both'.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? middleName,
    String? gender,
    required String phoneCode,
    required String phone,
    DateTime? dateOfBirth,
    required String profession,
    required String role,
  }) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    await user.updateDisplayName(fullName.trim());

    final roles = _rolesFromInput(role);

    await firestoreDb.collection('users').doc(user.uid).set(
      {
        'fullName': fullName.trim(),
        if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
        if (gender != null) 'gender': gender,
        'phoneCode': phoneCode.trim(),
        'phone': phone.trim(),
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
        'profession': profession.trim(),
        'email': email.trim(),
        'roles': roles,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Create self-profile doc for students (and dual-role users as students).
    if (roles.contains('client')) {
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
          if (middleName != null && middleName.trim().isNotEmpty) 'middleName': middleName.trim(),
          if (gender != null) 'gender': gender,
          'primaryContact': phone.trim(),
          'countryCode': phoneCode.trim(),
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
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

    await AdminProfileStorage.save(
      userName: fullName.trim(),
      userEmail: email.trim(),
    );

    // Claim a username -> uid mapping (guarded; never blocks signup).
    await FirestoreUsernameRepository()
        .register(uid: user.uid, username: email.split('@').first);

    await FirebaseAuth.instance.signOut();
  }

  // ── Add role to existing account ──────────────────────────────────────────

  /// Called when a user who already has one role wants to add another.
  ///
  /// Example: signed up as Tutor, now wants to also be a Student.
  ///
  /// [email] + [password] are used to verify the existing account.
  /// [newRole] is 'tutor' or 'client' — the role to add.
  ///
  /// Returns the new merged roles list on success.
  /// Throws [FirebaseAuthException] with code ROLE_ALREADY_EXISTS if the
  /// account already has this role.
  Future<List<String>> addRoleToExistingAccount({
    required String email,
    required String password,
    required String newRole,
  }) async {
    // Verify identity by signing in.
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    // Fetch current roles.
    final snap = await firestoreDb.collection('users').doc(user.uid).get();
    final raw = snap.data()?['roles'];
    final currentRoles =
        raw is List ? raw.cast<String>().toList() : <String>[];

    final newRoles = _rolesFromInput(newRole);

    // Check if role already exists.
    final alreadyHasAll = newRoles.every(currentRoles.contains);
    if (alreadyHasAll) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_ALREADY_EXISTS',
        message: 'Your account already has the ${newRole == 'client' ? 'Student' : 'Tutor'} role.',
      );
    }

    // Merge roles (no duplicates).
    final merged = {...currentRoles, ...newRoles}.toList();

    // Update Firestore roles.
    await firestoreDb.collection('users').doc(user.uid).set(
      {
        'roles': merged,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Create student self-profile doc if adding client role.
    if (newRoles.contains('client') && !currentRoles.contains('client')) {
      final name = snap.data()?['fullName'] as String? ??
          user.displayName?.trim() ??
          '';
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
          'name': name,
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

    await FirebaseAuth.instance.signOut();
    return merged;
  }


  // ── Login ─────────────────────────────────────────────────────────────────

  /// Signs in with email/password and validates that the account has the
  /// [expectedRole] ('tutor' or 'client').
  /// Throws [FirebaseAuthException] with code ROLE_MISMATCH on failure.
  Future<User> signIn({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await _assertRole(user.uid, expectedRole);
    firestoreDb.collection('users').doc(user.uid).set(
      {'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    ).ignore();
    AuditService.instance.log(
        action: 'login', entity: 'user', entityId: user.uid);
    return user;
  }

  /// Signs in with Google for an EXISTING account.
  /// Throws ROLE_MISMATCH or USER_NOT_FOUND as needed.
  Future<User?> signInWithGoogle({required String expectedRole}) async {
    final credential = await GoogleAuth.signIn();
    final user = credential.user!;
    final isNew = credential.additionalUserInfo?.isNewUser ?? false;

    if (isNew) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'USER_NOT_FOUND',
        message: 'No account found for this Google profile. Please sign up first.',
      );
    }

    await _assertRole(user.uid, expectedRole);
    firestoreDb.collection('users').doc(user.uid).set(
      {'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    ).ignore();
    return user;
  }

  /// Signs up with Google for a NEW account.
  /// [role] is 'tutor', 'client', or 'both'.
  Future<void> signUpWithGoogle({required String role}) async {
    final credential = await GoogleAuth.signIn();
    final user = credential.user!;
    final isNew = credential.additionalUserInfo?.isNewUser ?? false;

    if (!isNew) {
      // User already has an account. Check if they need a new role added.
      final snap = await firestoreDb.collection('users').doc(user.uid).get();
      final raw = snap.data()?['roles'];
      final currentRoles = raw is List ? raw.cast<String>().toList() : <String>[];
      
      final newRoles = _rolesFromInput(role);
      final alreadyHasAll = newRoles.every(currentRoles.contains);
      
      if (alreadyHasAll) {
        await FirebaseAuth.instance.signOut();
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'An account already exists for this Google profile. Please use the login screen.',
        );
      } else {
        // Add the new role
        final merged = {...currentRoles, ...newRoles}.toList();
        await firestoreDb.collection('users').doc(user.uid).set(
          {
            'roles': merged,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        
        // Add student profile if needed
        if (newRoles.contains('client') && !currentRoles.contains('client')) {
          final name = snap.data()?['fullName'] as String? ?? user.displayName?.trim() ?? '';
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
              'name': name,
              'primaryContact': '',
              'email': user.email ?? '',
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
        await FirebaseAuth.instance.signOut();
        return;
      }
    }

    final name = user.displayName?.trim() ?? '';
    final email = user.email?.trim() ?? '';
    final roles = _rolesFromInput(role);

    await firestoreDb.collection('users').doc(user.uid).set(
      {
        'fullName': name,
        'email': email,
        'roles': roles,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Create self-profile doc for students.
    if (roles.contains('client')) {
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
          'name': name,
          'primaryContact': '',
          'email': email,
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

    await AdminProfileStorage.save(userName: name, userEmail: email);

    // Claim a username -> uid mapping (guarded; never blocks signup).
    final unameSeed = email.split('@').first;
    await FirestoreUsernameRepository().register(
      uid: user.uid,
      username: unameSeed.isNotEmpty ? unameSeed : name,
    );

    await FirebaseAuth.instance.signOut();
  }

  // ── Sign-out ──────────────────────────────────────────────────────────────

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  // ── Role helpers ─────────────────────────────────────────────────────────

  /// Converts the signup role string to a Firestore roles array.
  static List<String> _rolesFromInput(String role) {
    if (role == 'both') return ['tutor', 'client'];
    if (role == 'tutor') return ['tutor'];
    return ['client'];
  }

  /// Validates that [uid]'s Firestore roles array contains [expectedRole].
  /// Signs out and throws ROLE_MISMATCH if not.
  Future<void> _assertRole(String uid, String expectedRole) async {
    DocumentSnapshot<Map<String, dynamic>>? snap;
    int attempts = 0;
    while (true) {
      try {
        snap = await firestoreDb.collection('users').doc(uid).get();
        break;
      } catch (e) {
        attempts++;
        if (attempts >= 3) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 200 * attempts));
      }
    }
    final raw = snap?.data()?['roles'];
    final List<String> roles = raw is List ? raw.cast<String>() : [];

    // If no roles array yet, fall back to inferring from enrollment subcollection.
    // NOTE: We do NOT use the clients subcollection here because students also
    // have a self-profile doc there — it would wrongly flag them as tutors.
    if (roles.isEmpty) {
      final inferred = await _inferRolesFromSubcollections(uid);
      if (inferred.isNotEmpty) {
        firestoreDb.collection('users').doc(uid).set(
          {'roles': inferred},
          SetOptions(merge: true),
        ).ignore();
        _assertRoleAgainstList(uid, inferred, expectedRole); // sync, may throw
        return;
      }
      // Fire-and-forget signOut so we throw IMMEDIATELY without yielding to
      // the event loop. This prevents authStateChanges from firing and
      // corrupting the navigator before the error can be displayed.
      FirebaseAuth.instance.signOut().ignore();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'Account has no role assigned. Please complete sign-up.',
      );
    }

    _assertRoleAgainstList(uid, roles, expectedRole); // sync, may throw
  }

  // Synchronous — no async/await so the ROLE_MISMATCH exception propagates
  // immediately back to _onLogin without yielding to the event loop.
  // signOut is fire-and-forget to avoid an authStateChanges race condition
  // that would show a grey screen before the error message is displayed.
  void _assertRoleAgainstList(
    String uid,
    List<String> roles,
    String expectedRole,
  ) {
    final wantsTutor = expectedRole == 'tutor';
    final hasTutor = roles.contains('tutor');
    final hasClient = roles.contains('client') || roles.contains('student');

    if (wantsTutor && !hasTutor) {
      FirebaseAuth.instance.signOut().ignore();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'This is a Student account. Please use the Student login.',
      );
    }
    if (!wantsTutor && !hasClient) {
      FirebaseAuth.instance.signOut().ignore();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'This is a Tutor account. Please use the Tutor login.',
      );
    }
  }

  /// Legacy fallback — checks enrollment subcollection to detect client role.
  /// Tutors must have a roles array in their user doc.
  Future<List<String>> _inferRolesFromSubcollections(String uid) async {
    bool isClient = false;
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('enrollment')
          .limit(1)
          .get();
      isClient = s.docs.isNotEmpty;
    } catch (_) {}
    return [if (isClient) 'client'];
  }


  // ── Role fetch (used by LandingScreen) ───────────────────────────────────

  Future<List<String>> fetchRoles(String uid) async {
    DocumentSnapshot<Map<String, dynamic>>? snap;
    int attempts = 0;
    while (true) {
      try {
        snap = await firestoreDb.collection('users').doc(uid).get();
        break;
      } catch (_) {
        attempts++;
        if (attempts >= 3) break;
        await Future.delayed(Duration(milliseconds: 200 * attempts));
      }
    }
    if (snap != null) {
      final raw = snap.data()?['roles'];
      if (raw is List && raw.isNotEmpty) return raw.cast<String>();
    }
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
