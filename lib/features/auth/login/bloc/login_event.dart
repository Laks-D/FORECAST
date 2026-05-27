import 'package:equatable/equatable.dart';

import '../../../../core/app/app_mode.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

final class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class LoginPasswordChanged extends LoginEvent {
  const LoginPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

final class LoginPasswordVisibilityToggled extends LoginEvent {
  const LoginPasswordVisibilityToggled();
}

/// Fired when the user taps the Login button.
///
/// [intendedMode] reflects the tab the user had selected (Tutor = admin,
/// Client = client).  The bloc validates that their Firestore roles include
/// the corresponding role and blocks sign-in otherwise.
final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.intendedMode});

  final AppMode intendedMode;

  @override
  List<Object?> get props => [intendedMode];
}

/// Same as [LoginSubmitted] but triggered via the Google button.
final class LoginWithGoogleSubmitted extends LoginEvent {
  const LoginWithGoogleSubmitted({required this.intendedMode});

  final AppMode intendedMode;

  @override
  List<Object?> get props => [intendedMode];
}
