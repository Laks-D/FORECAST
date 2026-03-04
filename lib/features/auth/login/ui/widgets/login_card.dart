import 'package:flutter/material.dart';

import 'login_fields.dart';
import 'login_footer_links.dart';
import 'login_submit_button.dart';

class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    this.onNewUserTap,
    this.onForgotPasswordTap,
  });

  final VoidCallback? onNewUserTap;
  final VoidCallback? onForgotPasswordTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoginFields(),
            const SizedBox(height: 18),
            const LoginSubmitButton(),
            const SizedBox(height: 10),
            LoginFooterLinks(
              onNewUserTap: onNewUserTap,
              onForgotPasswordTap: onForgotPasswordTap,
            ),
          ],
        ),
      ),
    );
  }
}
