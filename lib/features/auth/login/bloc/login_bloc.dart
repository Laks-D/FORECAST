import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/auth/username_key.dart';
import '../../../../core/auth/google_auth.dart';
import '../../../../core/app/app_mode.dart';
import '../../../../core/firebase/firestore_db.dart';

import 'login_event.dart';
import 'login_state.dart';

/// Handles authentication with role validation based on the selected tab.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<LoginSubmitted>(_onSubmitted);
    on<LoginWithGoogleSubmitted>(_onGoogleSubmitted);
  }

  FutureOr<void> _onEmailChanged(LoginEmailChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(email: event.email, status: LoginStatus.idle, errorMessage: null));
  }

  FutureOr<void> _onPasswordChanged(LoginPasswordChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(password: event.password, status: LoginStatus.idle, errorMessage: null));
  }

  FutureOr<void> _onPasswordVisibilityToggled(
    LoginPasswordVisibilityToggled event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(isPasswordObscured: !state.isPasswordObscured));
  }

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    if (!state.canSubmit || state.status == LoginStatus.submitting) return;

    emit(state.copyWith(status: LoginStatus.submitting, errorMessage: null));

    try {
      final resolvedEmail = await _resolveEmailFromIdentifier(state.email);
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: state.password,
      );

      await _assertRoleAccess(credential.user, event.intendedMode);
      await _upsertLoginTimestamp(credential.user);
      emit(state.copyWith(status: LoginStatus.success, email: resolvedEmail));
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'ROLE_MISMATCH' => (e.message ?? 'Use the correct login tab for this account.'),
        'network-request-failed' => 'No internet connection. Please try again.',
        _ => (e.message ?? 'Login failed (${e.code})'),
      };
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: message));
    } on FirebaseException catch (e) {
      final message = switch (e.code) {
        'permission-denied' => 'Database permission denied. Update Firestore rules.',
        'unavailable' => 'No internet connection (Firestore client is offline).',
        _ => (e.message ?? 'Database error (${e.code})'),
      };
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: message));
    } catch (_) {
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: 'Login failed'));
    }
  }

  Future<void> _onGoogleSubmitted(LoginWithGoogleSubmitted event, Emitter<LoginState> emit) async {
    if (state.status == LoginStatus.submitting) return;

    emit(state.copyWith(status: LoginStatus.submitting, errorMessage: null));

    try {
      final userCredential = await GoogleAuth.signIn();
      final user = userCredential.user;
      final email = user?.email;

      await _assertRoleAccess(user, event.intendedMode);
      await _upsertLoginTimestamp(user);

      emit(
        state.copyWith(
          status: LoginStatus.success,
          email: (email == null || email.trim().isEmpty) ? state.email : email,
          password: '',
        ),
      );
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: e.message ?? 'Google sign-in failed',
      ));
    } catch (e) {
      final msg = e.toString();
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: msg.contains('canceled') || msg.contains('cancelled')
            ? 'Sign-in cancelled'
            : 'Google sign-in failed. Please try again.',
      ));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _assertRoleAccess(User? user, AppMode intendedMode) async {
    if (user == null) return;

    final roles = await _resolveRoles(user.uid);
    if (roles.isDualRole) return;

    final needsClient = intendedMode == AppMode.client;
    final hasClient = roles.isClient;
    final hasTutor = roles.isTutor;

    if (needsClient && !hasClient && hasTutor) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'This account is tutor-only. Please use the Tutor login tab.',
      );
    }

    if (!needsClient && !hasTutor && hasClient) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'This account is student-only. Please use the Student login tab.',
      );
    }

    if (!hasClient && !hasTutor) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(
        code: 'ROLE_MISMATCH',
        message: 'Account role not set. Please complete the correct signup.',
      );
    }
  }

  Future<_RoleInfo> _resolveRoles(String uid) async {
    try {
      final snap = await firestoreDb.collection('users').doc(uid).get();
      final raw = snap.data()?['roles'];
      if (raw is List) {
        final roles = raw.cast<String>();
        final isClient = roles.contains('client') || roles.contains('student');
        final isTutor = roles.contains('tutor');
        return _RoleInfo(isClient: isClient, isTutor: isTutor);
      }
    } catch (_) {}

    bool isClient = false;
    bool isTutor = false;
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('enrollment')
          .limit(1)
          .get();
      isClient = s.docs.isNotEmpty;
    } catch (_) {}
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('clients')
          .limit(1)
          .get();
      isTutor = s.docs.isNotEmpty;
    } catch (_) {}
    if (!isTutor) {
      try {
        final s = await firestoreDb
            .collection('organizations')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .get();
        isTutor = s.docs.isNotEmpty;
      } catch (_) {}
    }
    if (isClient || isTutor) {
      firestoreDb.collection('users').doc(uid).set(
        {'roles': [if (isTutor) 'tutor', if (isClient) 'client']},
        SetOptions(merge: true),
      );
    }
    return _RoleInfo(isClient: isClient, isTutor: isTutor);
  }

  Future<String> _resolveEmailFromIdentifier(String identifierRaw) async {
    final identifier = identifierRaw.trim();
    if (identifier.isEmpty) {
      throw FirebaseAuthException(code: 'EMPTY_IDENTIFIER', message: 'Enter username or email');
    }

    final looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier);
    if (looksLikeEmail) return identifier;

    final usernameKey = usernameKeyFromInput(identifier);
    if (usernameKey.isEmpty || usernameKey.length < 3) {
      throw FirebaseAuthException(
        code: 'INVALID_USERNAME',
        message: 'Enter a valid username (at least 3 characters) or email',
      );
    }

    final snap = await firestoreDb.collection('usernames').doc(usernameKey).get();
    final mappedEmail = (snap.data()?['email'] as String?)?.trim();
    if (mappedEmail != null && mappedEmail.isNotEmpty) return mappedEmail;

    throw FirebaseAuthException(
      code: 'USERNAME_NOT_FOUND',
      message: 'Username not found. Create an account first.',
    );
  }

  /// Updates profile metadata on every login.
  /// Does NOT touch `roles` — roles are set at signup and QR enrollment only.
  Future<void> _upsertLoginTimestamp(User? user) async {
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await firestoreDb.collection('users').doc(uid).set(
        {
          'email': user?.email,
          'displayName': user?.displayName,
          'photoURL': user?.photoURL,
          'lastLoginAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}

class _RoleInfo {
  const _RoleInfo({required this.isClient, required this.isTutor});
  final bool isClient;
  final bool isTutor;
  bool get isDualRole => isClient && isTutor;
}
