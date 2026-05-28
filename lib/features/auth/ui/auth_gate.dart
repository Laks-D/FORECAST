import 'package:flutter/material.dart';

import '../../../core/auth/signup_controller.dart';
import 'new_login_screen.dart';
import 'role_selection_screen.dart';

/// Container for the entire unauthenticated flow.
///
/// [LandingScreen] returns this widget when [FirebaseAuth.currentUser] is null.
///
/// On first build it checks [SignupController] for pending signup state.  If
/// a signup just completed, it pushes [NewLoginScreen] for the correct role
/// (with the success message) on the very first frame instead of showing the
/// role-selection screen.
///
/// A [UniqueKey] is supplied by [LandingScreen] whenever the user transitions
/// from signed-in to signed-out so that [initState] is always called fresh
/// and pending state is never missed.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    // If a signup just completed, jump directly to the login screen for
    // the role that was signed up, carrying the success message.
    final role = SignupController.instance.pendingLoginRole;
    final msg = SignupController.instance.pendingSuccessMessage;

    if (role != null && msg != null) {
      SignupController.instance.pendingLoginRole = null;
      SignupController.instance.pendingSuccessMessage = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // 'both' role: user must choose which tab to sign in from.
        // Just show the success message on RoleSelectionScreen.
        if (role == 'both') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 4),
          ));
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewLoginScreen(
              role: role,
              pendingMessage: msg,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const RoleSelectionScreen();
  }
}
