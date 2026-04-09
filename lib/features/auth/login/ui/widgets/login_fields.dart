import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/login_bloc.dart';
import '../../bloc/login_event.dart';
import '../../bloc/login_state.dart';
import 'login_text_field.dart';

class LoginFields extends StatefulWidget {
  const LoginFields({
    super.key,
    required this.isClient,
  });

  final bool isClient;

  @override
  State<LoginFields> createState() => _LoginFieldsState();
}

class _LoginFieldsState extends State<LoginFields> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    final st = context.read<LoginBloc>().state;
    _emailController = TextEditingController(text: st.email);
    _passwordController = TextEditingController(text: st.password);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.isClient;

    return Column(
      children: [
        LoginTextField(
          controller: _emailController,
          labelText: isClient ? 'Client username' : 'Email',
          hintText: isClient ? 'client_test' : 'Your email or username',
          onChanged: (value) =>
              context.read<LoginBloc>().add(LoginEmailChanged(value)),
        ),
        const SizedBox(height: 14),
        BlocSelector<LoginBloc, LoginState, bool>(
          selector: (state) => state.isPasswordObscured,
          builder: (context, isObscured) {
            return LoginTextField(
              controller: _passwordController,
              labelText: 'Password',
              hintText: isClient ? 'client@123' : 'Enter your password',
              obscureText: isObscured,
              suffix: IconButton(
                icon: Icon(
                  isObscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => context
                    .read<LoginBloc>()
                    .add(const LoginPasswordVisibilityToggled()),
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
