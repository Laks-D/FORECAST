import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/login_controller.dart';
import '../repository/auth_repository.dart';
import '../../auth/forgot_password/ui/forgot_password_screen.dart';

/// Login screen for a specific [role] ('tutor' or 'client').
///
/// Shows the correct title ("Tutor Login" / "Student Login"), handles
/// email+password auth, validates the role, and surfaces errors inline.
///
/// After a successful signup (routed back here by [NewSignupScreen]),
/// [pendingMessage] is displayed as a SnackBar on first build.
class NewLoginScreen extends StatefulWidget {
  const NewLoginScreen({
    super.key,
    required this.role,
    this.pendingMessage,
  });

  /// 'tutor' or 'client'.
  final String role;

  /// Optional SnackBar message from a just-completed signup.
  final String? pendingMessage;

  @override
  State<NewLoginScreen> createState() => _NewLoginScreenState();
}

class _NewLoginScreenState extends State<NewLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  bool get _isTutor => widget.role == 'tutor';
  String get _roleLabel => _isTutor ? 'Tutor' : 'Student';
  Color get _accentColor =>
      _isTutor ? const Color(0xFF6C63FF) : const Color(0xFF00C4B4);

  @override
  void initState() {
    super.initState();
    // Show success message from a preceding signup.
    if (widget.pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.pendingMessage!),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 4),
        ));
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthRepository.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        expectedRole: widget.role,
      );
      // Record which tab was used — LandingScreen uses this to route
      // dual-role users to the correct dashboard.
      LoginController.instance.lastLoginRole = widget.role;
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);

    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Login failed. Please try again.';
        _loading = false;
      });
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => 'No account found with that email.',
      'USER_NOT_FOUND' =>
        'No account found for this Google profile. Please sign up first.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Incorrect email or password.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please wait a moment.',
      'network-request-failed' => 'No internet connection.',
      'ROLE_MISMATCH' => e.message ?? 'Wrong account type.',
      _ => e.message ?? 'Login failed (${e.code}).',
    };
  }

  void _goToForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  Future<void> _onGoogleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository.instance.signInWithGoogle(
        expectedRole: widget.role,
      );
      LoginController.instance.lastLoginRole = widget.role;
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('canceled') || msg.contains('cancelled')
            ? null
            : 'Google sign-in failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: scheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent dot
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isTutor
                        ? Icons.person_rounded
                        : Icons.menu_book_rounded,
                    color: _accentColor,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$_roleLabel Login',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your $_roleLabel account',
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 36),

                // Email
                _FieldLabel(label: 'Email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _fieldDecor(context, hint: 'you@example.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Password
                _FieldLabel(label: 'Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: _fieldDecor(context,
                      hint: 'Your password',
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: scheme.onSurface.withOpacity(0.5),
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      )),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _accentColor.withOpacity(0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Sign In',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── OR divider ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Google button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _onGoogleLogin,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.login, size: 20),
                    ),
                    label: Text(
                      'Continue with Google',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Forgot password link
                Center(
                  child: TextButton(
                    onPressed: _goToForgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: _accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Back to role selection
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.55),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign up',
                            style: TextStyle(
                              color: _accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecor(BuildContext context,
      {required String hint, Widget? suffix}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: scheme.onSurface.withOpacity(0.35), fontSize: 14),
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
      ),
    );
  }
}
