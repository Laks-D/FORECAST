import 'package:flutter/material.dart';

class LoginFooterLinks extends StatelessWidget {
  const LoginFooterLinks({
    super.key,
    this.onNewUserTap,
    this.onForgotPasswordTap,
  });

  final VoidCallback? onNewUserTap;
  final VoidCallback? onForgotPasswordTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurface.withOpacity(0.55),
      fontWeight: FontWeight.w600,
    );
    final link = theme.textTheme.bodySmall?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account?", style: muted),
            const SizedBox(width: 6),
            InkWell(
              onTap: onNewUserTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text('Sign up', style: link),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: onForgotPasswordTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text('Forgot password?', style: muted),
          ),
        ),
      ],
    );
  }
}
