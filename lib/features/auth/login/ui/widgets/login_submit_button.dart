import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/login_bloc.dart';
import '../../bloc/login_event.dart';
import '../../bloc/login_state.dart';

class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LoginBloc, LoginState, _ButtonModel>(
      selector: (state) => _ButtonModel(
        enabled: state.canSubmit,
        submitting: state.status == LoginStatus.submitting,
      ),
      builder: (context, model) {
        return SizedBox(
          width: 150,
          height: 44,
          child: ElevatedButton(
            onPressed: model.enabled && !model.submitting
                ? () => context.read<LoginBloc>().add(const LoginSubmitted())
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8FA4C2),
              disabledBackgroundColor: const Color(0xFF8FA4C2).withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: model.submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
