/// Global coordinator used between the signup form and the auth gate.
///
/// Solves the race condition where [FirebaseAuth.authStateChanges] fires the
/// moment [createUserWithEmailAndPassword] resolves — before the role has
/// been written to Firestore.
class SignupController {
  SignupController._();
  static final instance = SignupController._();

  /// While true [LandingScreen] must not route an authenticated user to the
  /// dashboard — it shows a loading indicator instead.
  bool isSignupInProgress = false;

  /// After a successful signup, the success message that the login screen
  /// should display as a SnackBar on its first frame.
  String? pendingSuccessMessage;

  /// The role that was just signed up, so [AuthGate] can jump directly to
  /// the correct login screen (instead of the role-selection screen) when it
  /// is re-created after the automatic sign-out at the end of signup.
  String? pendingLoginRole; // 'tutor' | 'client'
}
