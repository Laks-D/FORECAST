import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/widgets/app_card.dart';
import '../bloc/login_bloc.dart';
import '../bloc/login_state.dart';
import '../../signup/ui/signup_screen.dart';
import '../../forgot_password/ui/forgot_password_screen.dart';
import 'widgets/login_phone_frame.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginBloc(),
      child: BlocListener<LoginBloc, LoginState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) async {
          if (state.status == LoginStatus.success) {
            // No navigation needed: LandingScreen listens to FirebaseAuth and
            // will switch to the signed-in app automatically.
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
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = isLight ? Theme.of(context).scaffoldBackgroundColor : chrome.frameColor;
    final error = context.select((LoginBloc bloc) => bloc.state.errorMessage);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          LoginPhoneFrame(
            onNewUserTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SignupScreen(),
                ),
              );
            },
            onForgotPasswordTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              );
            },
          ),
          if (error != null && error.trim().isNotEmpty)
            Positioned(
              left: 18,
              right: 18,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: AppCard(
                  color: scheme.errorContainer.withOpacity(0.92),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    error,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
