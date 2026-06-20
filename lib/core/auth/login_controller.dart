import 'package:flutter/foundation.dart';

/// Records which login tab was last used so [LandingScreen] can route a
/// dual-role user to the correct dashboard without an extra round-trip.
///
/// Also exposes [loginInProgressNotifier] so [LandingScreen] can freeze its
/// auth-state routing while a login attempt is in flight, preventing the
/// grey-screen flicker caused by the brief Firebase Auth sign-in/sign-out
/// cycle that happens during role validation.
class LoginController {
  LoginController._();
  static final instance = LoginController._();

  /// 'tutor' or 'client' — set by [NewLoginScreen] on successful login.
  /// Null before any login has occurred this session.
  String? lastLoginRole;

  /// True while [NewLoginScreen] is actively attempting a sign-in.
  /// [LandingScreen] watches this notifier and skips auth-state routing
  /// while it is true, preventing the grey screen caused by the transient
  /// Firebase Auth sign-in that happens during role validation.
  final loginInProgressNotifier = ValueNotifier<bool>(false);

  bool get loginInProgress => loginInProgressNotifier.value;
  set loginInProgress(bool v) => loginInProgressNotifier.value = v;
}
