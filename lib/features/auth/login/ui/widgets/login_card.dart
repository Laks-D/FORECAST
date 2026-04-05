import 'package:flutter/material.dart';

import '../../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../../design_system/theme/app_visual_style.dart';
import 'login_fields.dart';
import 'login_footer_links.dart';
import 'login_google_button.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final chrome = AppChromeTheme.of(context);
    final visual = AppVisualStyle.of(context);

    final shadows = visual.neumorphism
        ? AppVisualStyle.neumorphicShadows(
            context,
            blurRadius: 28,
            offset: const Offset(8, 8),
            shadowOpacityLight: 0.10,
          )
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(40),
        boxShadow: shadows,
        border: Border.all(
          color: chrome.mutedColor.withOpacity(visual.neumorphism ? 0.14 : 0.10),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chrome.mutedColor.withOpacity(0.12),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: scheme.onSurface.withOpacity(0.70),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Log in',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 22),
            const LoginFields(),
            const SizedBox(height: 18),
            const LoginSubmitButton(),
            const SizedBox(height: 18),
            const LoginGoogleButton(),
            const SizedBox(height: 14),
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
