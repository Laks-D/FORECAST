import 'package:flutter/material.dart';

import '../../../../../design_system/theme/app_chrome_theme.dart';
import 'login_card.dart';

class LoginPhoneFrame extends StatelessWidget {
  const LoginPhoneFrame({
    super.key,
    this.onNewUserTap,
    this.onForgotPasswordTap,
  });

  final VoidCallback? onNewUserTap;
  final VoidCallback? onForgotPasswordTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final statusTop = MediaQuery.viewPaddingOf(context).top;
        final chrome = AppChromeTheme.of(context);
        final isLight = Theme.of(context).brightness == Brightness.light;
        final frameColor = isLight ? Theme.of(context).scaffoldBackgroundColor : chrome.frameColor;

        return SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: frameColor,
                  ),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: statusTop,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: frameColor,
                    ),
                  ),
                ),
              ),

              // Login card near bottom
              Positioned.fill(
                top: statusTop,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: LoginCard(
                            onNewUserTap: onNewUserTap,
                            onForgotPasswordTap: onForgotPasswordTap,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
