import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../design_system/theme/app_chrome_theme.dart';
import '../../bloc/login_bloc.dart';
import '../../bloc/login_event.dart';
import '../../bloc/login_state.dart';

class LoginGoogleButton extends StatelessWidget {
  const LoginGoogleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chrome = AppChromeTheme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurface.withOpacity(0.55),
          fontWeight: FontWeight.w600,
        );

    Widget googleWideButton({
      required bool submitting,
    }) {
      final textStyle = theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface.withOpacity(0.85),
      );

      return SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: submitting
              ? null
              : () => context.read<LoginBloc>().add(const LoginWithGoogleSubmitted()),
          style: OutlinedButton.styleFrom(
            backgroundColor: scheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: chrome.mutedColor.withOpacity(0.18)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chrome.mutedColor.withOpacity(0.12),
                ),
                child: Text(
                  'G',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface.withOpacity(0.90),
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Continue with Google',
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BlocSelector<LoginBloc, LoginState, bool>(
      selector: (state) => state.status == LoginStatus.submitting,
      builder: (context, submitting) {
        return Column(
          children: [
            Text('Or log in with', style: labelStyle),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: googleWideButton(submitting: submitting),
            ),
          ],
        );
      },
    );
  }
}
