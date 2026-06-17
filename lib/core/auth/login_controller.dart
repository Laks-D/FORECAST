/// Records which login tab was last used so [LandingScreen] can route a
/// dual-role user to the correct dashboard without an extra round-trip.
class LoginController {
  LoginController._();
  static final instance = LoginController._();

  /// 'tutor' or 'client' — set by [NewLoginScreen] on successful login.
  /// Null before any login has occurred this session.
  String? lastLoginRole;
}
