import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../../design_system/theme/app_visual_style.dart';
import '../../bloc/login_bloc.dart';
import '../../bloc/login_event.dart';
import '../../bloc/login_state.dart';

class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton({super.key});

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final theme = Theme.of(context);
    final visual = AppVisualStyle.of(context);

    return BlocSelector<LoginBloc, LoginState, _ButtonModel>(
      selector: (state) => _ButtonModel(
        enabled: state.canSubmit,
        submitting: state.status == LoginStatus.submitting,
      ),
      builder: (context, model) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: model.enabled && !model.submitting
                ? () => context.read<LoginBloc>().add(const LoginSubmitted())
                : null,
            style: visual.neumorphism
                ? Theme.of(context).elevatedButtonTheme.style?.copyWith(
                      textStyle: WidgetStatePropertyAll(
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                : ElevatedButton.styleFrom(
                    backgroundColor: chrome.textColor,
                    foregroundColor: chrome.surfaceColor,
                    disabledBackgroundColor: chrome.textColor.withOpacity(0.35),
                    disabledForegroundColor: chrome.surfaceColor.withOpacity(0.75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            child: model.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Login'),
          ),
        );
      },
    );
  }
}

class _ButtonModel {
  const _ButtonModel({required this.enabled, required this.submitting});

  final bool enabled;
  final bool submitting;

  @override
  bool operator ==(Object other) {
    return other is _ButtonModel && other.enabled == enabled && other.submitting == submitting;
  }

  @override
  int get hashCode => Object.hash(enabled, submitting);
}
