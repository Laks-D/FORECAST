import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';
import '../bloc/login_bloc.dart';
import '../bloc/login_state.dart';
import '../../../dashboard/ui/dashboard_screen.dart';
import '../../signup/ui/signup_screen.dart';
import 'widgets/login_phone_frame.dart';

String _nameFromEmail(String email) {
  final trimmed = email.trim();
  final at = trimmed.indexOf('@');
  final raw = (at > 0 ? trimmed.substring(0, at) : trimmed).trim();
  if (raw.isEmpty) return 'User';
  final replaced = raw.replaceAll(RegExp(r'[._-]+'), ' ').trim();
  if (replaced.isEmpty) return 'User';
  return replaced
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p.length == 1 ? p.toUpperCase() : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: BlocListener<LoginBloc, LoginState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == LoginStatus.success) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => DashboardScreen(
                  initialUserName: _nameFromEmail(state.email),
                  initialUserEmail: state.email,
                ),
              ),
            );
          }
        },
        child: const _LoginView(),
      ),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: LoginPhoneFrame(
        onNewUserTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SignupScreen(),
            ),
          );
        },
      ),
    );
  }
}
