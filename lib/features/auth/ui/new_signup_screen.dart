import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/signup_controller.dart';
import '../repository/auth_repository.dart';

/// Signup screen for a specific [role] ('tutor' or 'client').
///
/// On success:
///  1. Writes role + profile to Firestore (user IS authenticated at this point).
///  2. Sets [SignupController] pending message and role.
///  3. Pops the entire stack back to the first route.
///  4. Signs out — [LandingScreen] reacts (user→null) and re-creates [AuthGate].
///  5. [AuthGate] reads the pending state → jumps to [NewLoginScreen] with the
///     success SnackBar already queued.
class NewSignupScreen extends StatefulWidget {
  const NewSignupScreen({super.key, required this.role});

  final String role; // 'tutor' | 'client'

  @override
  State<NewSignupScreen> createState() => _NewSignupScreenState();
}

class _NewSignupScreenState extends State<NewSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  bool get _isTutor => widget.role == 'tutor';
  String get _roleLabel => _isTutor ? 'Tutor' : 'Student';
  Color get _accentColor =>
      _isTutor ? const Color(0xFF6C63FF) : const Color(0xFF00C4B4);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _profCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    // Block LandingScreen from routing to the dashboard when authStateChanges
    // fires the instant createUserWithEmailAndPassword resolves.
    SignupController.instance.isSignupInProgress = true;

    try {
      await AuthRepository.instance.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
        profession: _profCtrl.text.trim(),
        role: widget.role,
        // AuthRepository.signUp calls signOut() at the end.
      );

      // ── Success path ──────────────────────────────────────────────────────
      // Store state that AuthGate will read when it is re-created after signOut.
      SignupController.instance.pendingSuccessMessage =
          'Account created! Please sign in.';
      SignupController.instance.pendingLoginRole = widget.role;

      // Pop ALL routes (signup + login) back to LandingScreen (route.isFirst).
      // LandingScreen currently shows a loading spinner (isSignupInProgress=true).
      if (!mounted) {
        // Widget disposed during async gap — state already set, signOut was
        // called inside AuthRepository.signUp, so just clear the flag.
        SignupController.instance.isSignupInProgress = false;
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);

      // AuthRepository.signUp already called signOut().
      // authStateChanges now fires: user==null → LandingScreen shows AuthGate.
      // AuthGate reads pendingLoginRole/pendingSuccessMessage → shows login.
      // Clear the flag so LandingScreen stops showing the spinner.
      SignupController.instance.isSignupInProgress = false;
    } on FirebaseAuthException catch (e) {
      SignupController.instance.isSignupInProgress = false;
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    } catch (e) {
      SignupController.instance.isSignupInProgress = false;
      if (!mounted) return;
      setState(() {
        _error = 'Sign-up failed. Please try again.';
        _loading = false;
      });
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' =>
        'An account with this email already exists. Please sign in.',
      'weak-password' => 'Password is too weak (min 6 characters).',
      'invalid-email' => 'Enter a valid email address.',
      'network-request-failed' => 'No internet connection.',
      _ => e.message ?? 'Sign-up failed (${e.code}).',
    };
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isTutor
                        ? Icons.person_add_rounded
                        : Icons.school_rounded,
                    color: _accentColor,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create $_roleLabel Account',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fill in your details to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 28),

                _label('Full Name'),
                const SizedBox(height: 6),
                _field(context,
                    controller: _nameCtrl,
                    hint: 'Your full name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),

                _label(_isTutor ? 'Profession' : 'Grade / School'),
                const SizedBox(height: 6),
                _field(context,
                    controller: _profCtrl,
                    hint: _isTutor
                        ? 'e.g. Mathematics Teacher'
                        : 'e.g. Grade 10 / Delhi Public School'),
                const SizedBox(height: 16),

                _label('Email'),
                const SizedBox(height: 6),
                _field(context,
                    controller: _emailCtrl,
                    hint: 'you@example.com',
                    keyboard: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    }),
                const SizedBox(height: 16),

                _label('Password'),
                const SizedBox(height: 6),
                _field(context,
                    controller: _passCtrl,
                    hint: 'Min 6 characters',
                    obscure: _obscurePass,
                    suffix: _eyeIcon(
                        _obscurePass,
                        () => setState(() => _obscurePass = !_obscurePass)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    }),
                const SizedBox(height: 16),

                _label('Confirm Password'),
                const SizedBox(height: 6),
                _field(context,
                    controller: _confirmCtrl,
                    hint: 'Repeat your password',
                    obscure: _obscureConfirm,
                    suffix: _eyeIcon(
                        _obscureConfirm,
                        () => setState(
                            () => _obscureConfirm = !_obscureConfirm)),
                    validator: (v) {
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    }),

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

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _onSignUp,
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
                            'Create Account',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.55),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign in',
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
        ),
      );

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final InputDecoration decor = InputDecoration(
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

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      decoration: decor,
      validator: validator,
    );
  }

  Widget _eyeIcon(bool obscured, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
      onPressed: onTap,
    );
  }
}
