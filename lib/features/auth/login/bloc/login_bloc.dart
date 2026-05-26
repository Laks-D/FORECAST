import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/app/app_mode.dart';
import '../../../../core/auth/username_key.dart';
import '../../../../core/auth/google_auth.dart';
import '../../../../core/firebase/firestore_db.dart';

import 'login_event.dart';
import 'login_state.dart';

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

      // Validate that the user's roles match the tab they logged in through.
      final accessError = await _checkRoleAccess(credential.user?.uid, event.intendedMode);
      if (accessError != null) {
        await FirebaseAuth.instance.signOut();
        emit(state.copyWith(status: LoginStatus.failure, errorMessage: accessError));
        return;
      }

      await _upsertLoginTimestamp(credential.user);
      emit(state.copyWith(status: LoginStatus.success, email: resolvedEmail));
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
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

      // Validate roles against the tab they used.
      final accessError = await _checkRoleAccess(user?.uid, event.intendedMode);
      if (accessError != null) {
        await FirebaseAuth.instance.signOut();
        emit(state.copyWith(status: LoginStatus.failure, errorMessage: accessError));
        return;
      }

      await _upsertLoginTimestamp(user);

      emit(
        state.copyWith(
          status: LoginStatus.success,
          email: (email == null || email.trim().isEmpty) ? state.email : email,
          password: '',
        ),
      );
    } on FirebaseAuthException catch (e) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: e.message ?? 'Google sign-in failed',
        ),
      );
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

  // ── Role validation ───────────────────────────────────────────────────────

  /// Returns an error message if the user's stored roles do not permit access
  /// via [intendedMode], or `null` if access is allowed.
  ///
  /// - Tutor tab  (AppMode.admin)  → requires `'tutor'` in roles
  /// - Student tab (AppMode.client) → requires `'student'` in roles
  ///
  /// If Firestore is unavailable the check is skipped (fail-open) so a
  /// network blip never hard-locks a legitimate user.
  Future<String?> _checkRoleAccess(String? uid, AppMode intendedMode) async {
    if (uid == null) return null;

    final List<String> roles;
    try {
      final doc = await firestoreDb.collection('users').doc(uid).get();
      roles = (doc.data()?['roles'] as List?)?.cast<String>() ?? [];
    } on FirebaseException catch (e) {
      // Fail-closed: we cannot verify the role so we block the login and ask
      // the user to check their connection.  This prevents a student from
      // accidentally (or deliberately) entering the tutor dashboard just
      // because Firestore was temporarily unreachable.
      final isOffline = e.code == 'unavailable' || e.code == 'network-request-failed';
      return isOffline
          ? 'Could not verify your account. Check your internet connection and try again.'
          : 'Account verification failed (${e.code}). Please try again.';
    } catch (_) {
      return 'Could not verify your account. Please check your connection and try again.';
    }

    // New user with no roles yet (e.g. first Google sign-in before signup form).
    // Let them through; the signup flow will assign the correct role.
    if (roles.isEmpty) return null;

    if (intendedMode == AppMode.admin && !roles.contains('tutor')) {
      return roles.contains('student')
          ? 'You are registered as a student. Please use the Student tab to log in.'
          : 'Your account does not have tutor access. Please sign up as a tutor.';
    }

    if (intendedMode == AppMode.client && !roles.contains('student')) {
      return roles.contains('tutor')
          ? 'You are registered as a tutor. Please use the Tutor tab to log in.'
          : 'You are not enrolled under any tutor yet. Please scan a QR code first.';
    }

    return null; // Access granted.
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
    final data = snap.data();
    final mappedEmail = (data?['email'] as String?)?.trim();
    if (mappedEmail != null && mappedEmail.isNotEmpty) return mappedEmail;

    throw FirebaseAuthException(
      code: 'USERNAME_NOT_FOUND',
      message: 'Username not found. Create an account first.',
    );
  }

  /// Only updates non-role fields on login — roles are set at signup/QR
  /// enrollment and must not be modified here.
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
          // Intentionally NOT setting 'roles' here — roles are assigned at
          // signup (based on the tab selected) and via QR enrollment.
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Keep the Firebase login flow successful even if Firestore sync fails.
    }
  }
}
