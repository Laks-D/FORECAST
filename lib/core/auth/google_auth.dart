import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Shared Google sign-in helper used by both Login and Signup flows.
class GoogleAuth {
  GoogleAuth._();

  static bool _initialized = false;

  static Future<UserCredential> signIn() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return FirebaseAuth.instance.signInWithPopup(provider);
    }
    // Native/mobile flow
    if (!_initialized) {
      await GoogleSignIn.instance.initialize();
      _initialized = true;
    }

    final googleAccount = await GoogleSignIn.instance.authenticate();
    final auth = googleAccount.authentication;
    final idToken = auth.idToken;

    if (idToken == null || idToken.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'GOOGLE_TOKENS_MISSING',
        message: 'Google sign-in failed: missing tokens',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }
}
