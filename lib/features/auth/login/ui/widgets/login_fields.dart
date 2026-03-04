import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/login_bloc.dart';
import '../../bloc/login_event.dart';
import '../../bloc/login_state.dart';
import 'login_text_field.dart';

class LoginFields extends StatelessWidget {
  const LoginFields({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LoginTextField(
          hintText: 'Username',
          onChanged: (value) => context.read<LoginBloc>().add(LoginEmailChanged(value)),
        ),
        const SizedBox(height: 14),
        BlocSelector<LoginBloc, LoginState, bool>(
          selector: (state) => state.isPasswordObscured,
          builder: (context, isObscured) {
            return LoginTextField(
              hintText: 'Password',
              obscureText: isObscured,
              suffix: IconButton(
                icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
                onPressed: () => context.read<LoginBloc>().add(const LoginPasswordVisibilityToggled()),
              ),
              onChanged: (value) =>
                  context.read<LoginBloc>().add(LoginPasswordChanged(value)),
            );
          },
        ),
      ],
    );
  }
}
