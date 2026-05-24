import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      await _upsertUserProfile(credential.user);
      emit(state.copyWith(status: LoginStatus.success, email: resolvedEmail));
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'network-request-failed' => 'No internet connection. Please try again.',
        _ => (e.message ?? 'Login failed (${e.code})'),
      };
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          errorMessage: message,
        ),
      );
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

      // Upsert the user profile — creates doc on first sign-in, merges on
      // subsequent ones.  We never block Google Sign-In based on Firestore
      // existence because the signup Firestore write can legitimately fail
      // (network unavailable) while Firebase Auth still succeeds.
      await _upsertUserProfile(user);

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
      // Surface actionable errors (e.g. cancelled by user) rather than a generic message.
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: msg.contains('canceled') || msg.contains('cancelled')
            ? 'Sign-in cancelled'
            : 'Google sign-in failed. Please try again.',
      ));
    }
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
    final data = snap.data();
    final mappedEmail = (data?['email'] as String?)?.trim();
    if (mappedEmail != null && mappedEmail.isNotEmpty) return mappedEmail;

    throw FirebaseAuthException(
      code: 'USERNAME_NOT_FOUND',
      message: 'Username not found. Create an account first.',
    );
  }

  Future<void> _upsertUserProfile(User? user) async {
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await firestoreDb.collection('users').doc(uid).set(
        {
          'email': user?.email,
          'displayName': user?.displayName,
          'photoURL': user?.photoURL,
          'lastLoginAt': FieldValue.serverTimestamp(),
          // Ensure every signed-in user has at least the 'tutor' role so
          // _checkRoles() in LandingScreen doesn't mis-route them to client mode.
          // arrayUnion is safe — it won't overwrite 'student' if already set.
          'roles': FieldValue.arrayUnion(['tutor']),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Keep the Firebase login flow successful even if Firestore sync fails.
    }
  }

}
