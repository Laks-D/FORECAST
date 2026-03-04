import 'package:equatable/equatable.dart';

enum LoginStatus { idle, submitting, success, failure }

final class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.password = '',
    this.isPasswordObscured = true,
    this.status = LoginStatus.idle,
    this.errorMessage,
  });

  final String email;
  final String password;
  final bool isPasswordObscured;
  final LoginStatus status;
  final String? errorMessage;

  bool get canSubmit => email.trim().isNotEmpty && password.isNotEmpty;

  LoginState copyWith({
    String? email,
    String? password,
    bool? isPasswordObscured,
    LoginStatus? status,
    String? errorMessage,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      isPasswordObscured: isPasswordObscured ?? this.isPasswordObscured,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, password, isPasswordObscured, status, errorMessage];
}
