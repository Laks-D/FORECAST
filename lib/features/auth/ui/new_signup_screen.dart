import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/signup_controller.dart';
import '../../../core/utils/date_utils.dart';
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
  final _middleNameCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  final _phoneCodeCtrl = TextEditingController(text: '+91');
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _gender;
  DateTime? _dob;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  bool get _isTutor => widget.role == 'tutor';
  String get _roleLabel => _isTutor ? 'Tutor' : 'Student';
  Color get _accentColor => _isTutor ? const Color(0xFF6C63FF) : const Color(0xFF00C4B4);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _middleNameCtrl.dispose();
    _profCtrl.dispose();
    _phoneCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_dob == null) {
      setState(() => _error = 'Please select your Date of Birth');
      return;
    }

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
        middleName: _middleNameCtrl.text.trim(),
        gender: _gender,
        phoneCode: _phoneCodeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        dateOfBirth: _dob,
        profession: _profCtrl.text.trim(),
        role: widget.role,
      );

      // ── Success path ──────────────────────────────────────────────────────
      SignupController.instance.pendingSuccessMessage =
          'Account created! Please sign in.';
      SignupController.instance.pendingLoginRole = widget.role;

      if (!mounted) {
        SignupController.instance.isSignupInProgress = false;
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
      SignupController.instance.isSignupInProgress = false;

    } on FirebaseAuthException catch (e) {
      SignupController.instance.isSignupInProgress = false;
      if (!mounted) return;

      // ── Email already exists: attempt seamless role addition ───────────────
      if (e.code == 'email-already-in-use') {
        try {
          await AuthRepository.instance.addRoleToExistingAccount(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            newRole: widget.role,
          );
          SignupController.instance.pendingSuccessMessage =
              '${_isTutor ? "Tutor" : "Student"} role added! Please sign in.';
          SignupController.instance.pendingLoginRole = widget.role;

          if (!mounted) {
            SignupController.instance.isSignupInProgress = false;
            return;
          }
          Navigator.of(context).popUntil((route) => route.isFirst);
          SignupController.instance.isSignupInProgress = false;
          return;
        } catch (_) {
          // If the password was wrong, fallback to showing the dialog
          if (!mounted) {
            SignupController.instance.isSignupInProgress = false;
            return;
          }
          setState(() => _loading = false);
          await _showAddRoleDialog(_emailCtrl.text.trim());
          return;
        }
      }

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

  /// Shows a dialog asking for the existing account's password to confirm
  /// identity, then adds the new role to the existing account.
  Future<void> _showAddRoleDialog(String email) async {
    final roleLabel = _isTutor ? 'Tutor' : 'Student';
    final existingLabel = _isTutor ? 'Student' : 'Tutor';
    final passCtrl = TextEditingController();
    bool dialogLoading = false;
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_circle_outline,
                      color: _accentColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add $roleLabel Role',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'An account already exists for $email. '
                    'It looks like you registered as a $existingLabel.\n\n'
                    'Enter your existing password for this account to also add the $roleLabel role.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Existing password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          final pass = passCtrl.text;
                          if (pass.isEmpty) {
                            setDlgState(
                                () => dialogError = 'Enter your password');
                            return;
                          }
                          setDlgState(() {
                            dialogLoading = true;
                            dialogError = null;
                          });
                          try {
                            await AuthRepository.instance
                                .addRoleToExistingAccount(
                              email: email,
                              password: pass,
                              newRole: widget.role,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } on FirebaseAuthException catch (e) {
                            setDlgState(() {
                              dialogLoading = false;
                              dialogError = switch (e.code) {
                                'wrong-password' ||
                                'invalid-credential' =>
                                  'Incorrect password.',
                                'ROLE_ALREADY_EXISTS' =>
                                  e.message ?? 'Role already added.',
                                'too-many-requests' =>
                                  'Too many attempts. Try later.',
                                _ => e.message ?? 'Failed (${e.code}).',
                              };
                            });
                          } catch (_) {
                            setDlgState(() {
                              dialogLoading = false;
                              dialogError = 'Something went wrong. Try again.';
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                      backgroundColor: _accentColor),
                  child: dialogLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Add $roleLabel Role'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (confirmed == true) {
      // Role added successfully — send user back to sign in.
      SignupController.instance.pendingSuccessMessage =
          '$roleLabel role added! You can now sign in via either tab.';
      SignupController.instance.pendingLoginRole = widget.role;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' =>
        'This email already has an account. Use the Sign In tab instead.',
      'weak-password' => 'Password is too weak (min 6 characters).',
      'invalid-email' => 'Enter a valid email address.',
      'network-request-failed' => 'No internet connection.',
      'ROLE_ALREADY_EXISTS' => e.message ?? 'You already have this role.',
      _ => e.message ?? 'Sign-up failed (${e.code}).',
    };
  }


  Future<void> _onGoogleSignUp() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    SignupController.instance.isSignupInProgress = true;
    try {
      await AuthRepository.instance.signUpWithGoogle(role: widget.role);

      SignupController.instance.pendingSuccessMessage =
          'Account created! Please sign in with Google.';
      SignupController.instance.pendingLoginRole = widget.role;

      if (!mounted) {
        SignupController.instance.isSignupInProgress = false;
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      final msg = e.toString();
      setState(() {
        _error = msg.contains('canceled') || msg.contains('cancelled')
            ? null
            : 'Google sign-up failed. Please try again.';
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

                _field(context,
                    controller: _nameCtrl,
                    label: 'Full Name *',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),

                _field(context,
                    controller: _middleNameCtrl,
                    label: 'Middle Name (optional)'),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _gender,
                  validator: (v) => v == null ? 'Required' : null,
                  decoration: _inputDecor(context, 'Gender *'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 16),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: _field(context,
                          controller: _phoneCodeCtrl,
                          label: 'Code'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(context,
                          controller: _phoneCtrl,
                          label: 'Phone *',
                          keyboard: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _field(context,
                    controller: _emailCtrl,
                    label: 'Email *',
                    keyboard: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    }),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dob = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: _inputDecor(context, 'Date of birth *'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dob != null ? AppDateUtils.displayDate(_dob!) : '',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        Icon(Icons.calendar_today, size: 20, color: scheme.onSurface.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                _field(context,
                    controller: _profCtrl,
                    label: _isTutor ? 'Profession *' : 'Grade / School *'),
                const SizedBox(height: 16),

                _field(context,
                    controller: _passCtrl,
                    label: 'Password *',
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

                _field(context,
                    controller: _confirmCtrl,
                    label: 'Confirm Password *',
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

                const SizedBox(height: 16),

                // ── OR divider ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: scheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: scheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Sign up with Google ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _onGoogleSignUp,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.login, size: 20),
                    ),
                    label: Text(
                      'Sign up with Google',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Back to role selection
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
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

  InputDecoration _inputDecor(BuildContext context, String label, {Widget? suffix}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle:
          TextStyle(color: scheme.onSurface.withOpacity(0.55), fontSize: 14),
      floatingLabelStyle: TextStyle(color: _accentColor, fontSize: 14),
      filled: true,
      fillColor: Colors.transparent,
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final decor = _inputDecor(context, label, suffix: suffix);


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
