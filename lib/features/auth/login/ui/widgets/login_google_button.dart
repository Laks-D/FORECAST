import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/login_bloc.dart';
import '../../bloc/login_event.dart';
import '../../bloc/login_state.dart';

class LoginGoogleButton extends StatelessWidget {
  const LoginGoogleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LoginBloc, LoginState, bool>(
      selector: (state) => state.status == LoginStatus.submitting,
      builder: (context, submitting) {
        return SizedBox(
          width: 220,
          height: 44,
          child: OutlinedButton(
            onPressed: submitting
                ? null
                : () => context.read<LoginBloc>().add(const LoginWithGoogleSubmitted()),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(color: Colors.black.withOpacity(0.15)),
            ),
            child: const Text(
              'Continue with Google',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
