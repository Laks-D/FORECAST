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

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<LoginSubmitted>(_onSubmitted);
    on<LoginWithGoogleSubmitted>(_onGoogleSubmitted);
  }

  // Client-mode login policy (overrideable via --dart-define if needed).
  static const String _clientLoginUser = String.fromEnvironment(
    'CLIENT_LOGIN_USER',
    defaultValue: 'client_test',
  );
  static const String _clientLoginPassword = String.fromEnvironment(
    'CLIENT_LOGIN_PASS',
    defaultValue: 'client@123',
  );

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
      if (AppModeConfig.isClient) {
        final identifier = state.email.trim().toLowerCase();
        if (identifier != _clientLoginUser.trim().toLowerCase()) {
          throw FirebaseAuthException(
            code: 'CLIENT_LOGIN_USER_REQUIRED',
            message: 'Client login: use $_clientLoginUser',
          );
        }
        if (state.password != _clientLoginPassword) {
          throw FirebaseAuthException(
            code: 'CLIENT_LOGIN_WRONG_PASSWORD',
            message: 'Client login: wrong password',
          );
        }
      }

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

      if (user != null) {
        // Check if this account is already registered in our backend
        final userDoc = await firestoreDb.collection('users').doc(user.uid).get();
        bool exists = userDoc.exists;
        
        if (!exists && email != null && email.isNotEmpty) {
          final emailQuery = await firestoreDb.collection('users').where('email', isEqualTo: email).limit(1).get();
          if (emailQuery.docs.isNotEmpty) {
            exists = true;
          }
        }

        if (!exists) {
          // Sign out immediately so we don't leave an orphaned session
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'ACCOUNT_NOT_FOUND',
            message: 'Account not registered. Please sign up instead.',
          );
        }
      }

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
    } catch (_) {
      emit(state.copyWith(status: LoginStatus.failure, errorMessage: 'Google sign-in failed'));
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
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Keep the Firebase login flow successful even if Firestore sync fails.
    }
  }

}
