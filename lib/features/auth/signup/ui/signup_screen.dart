import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/google_auth.dart';
import '../../../../core/firebase/firestore_db.dart';
import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/storage/signup_profile_storage.dart';
import '../../../../core/app/widgets/app_mode_selector.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../../design_system/theme/app_visual_style.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _professionController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Uint8List? _profileImageBytes;
  double _profileAlignX = 0;
  double _profileAlignY = 0;

  bool _acceptTerms = true;
  bool _isGoogleSignup = false;
  User? _googleUser;
  String? _googlePhotoUrl;

  Alignment get _profileImageAlignment =>
      Alignment(_profileAlignX, _profileAlignY);

  Future<void> _openProfileImageEditor({
    required Uint8List bytes,
    required Alignment initialAlignment,
  }) async {
    final result = await Navigator.of(context).push<_SignupProfileEditorResult>(
      MaterialPageRoute<_SignupProfileEditorResult>(
        builder: (_) => _SignupProfileEditorScreen(
          initialBytes: bytes,
          initialAlignment: initialAlignment,
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _profileImageBytes = result.bytes;
      _profileAlignX = result.alignment.x;
      _profileAlignY = result.alignment.y;
    });
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _openProfileImageEditor(
        bytes: bytes,
        initialAlignment: Alignment.center,
      );
    } catch (_) {
      // Ignore picker failures.
    }
  }

  Future<void> _showProfileImageOptions() async {
    final action = await showModalBottomSheet<ProfileImageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () =>
                    Navigator.of(context).pop(ProfileImageAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () =>
                    Navigator.of(context).pop(ProfileImageAction.gallery),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    final source = action == ProfileImageAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    await _pickProfileImage(source);
  }

  final String _nationality = 'India';
  final String _currency = '₹';

  @override
  void dispose() {
    _fullNameController.dispose();
    _professionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _saveUserToFirestore(String? uid) async {
    if (uid == null) return;
    try {
      final userRef = firestoreDb.collection('users').doc(uid);
      await userRef.set(
        {
          'fullName': _fullNameController.text.trim(),
          'profession': _professionController.text.trim(),
          'nationality': _nationality,
          'currency': _currency,
          'email': _emailController.text.trim(),
          if (_googlePhotoUrl != null) 'photoURL': _googlePhotoUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      final message = switch (e.code) {
        'permission-denied' =>
          'Database permission denied. Update Firestore rules.',
        'unavailable' =>
          'No internet connection (Firestore client is offline).',
        _ => (e.message ?? 'Database error (${e.code})'),
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved your account, but profile sync needs a retry.'),
          ),
        );
      }
    }
  }

  Future<void> _onFinishRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    if (!_isGoogleSignup) {
      final password = _passwordController.text;
      if (password.isEmpty) return;

      try {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await _saveUserToFirestore(credential.user?.uid);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Account already exists — signed you in.')),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
            return;
          } on FirebaseAuthException {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Email already registered. Please log in or reset your password.'),
              ),
            );
            return;
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Signup failed (${e.code})')),
        );
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup failed')),
        );
        return;
      }
    } else {
      // It's a Google signup, user is already authenticated
      await _saveUserToFirestore(_googleUser?.uid);
    }

    final profile = SignupProfileData(
      fullName: _fullNameController.text.trim(),
      profession: _professionController.text.trim(),
      nationality: _nationality,
      currency: _currency,
      email: email,
    );

    await SignupProfileStorage.saveProfile(profile);
    if (!mounted) return;

    // Ensure global default currency reflects saved profile.
    try {
      context.read<UserProfileCubit>().refresh();
    } catch (_) {}

    // No navigation needed: LandingScreen listens to FirebaseAuth and will
    // switch to the signed-in app automatically.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = AppVisualStyle.of(context);

    Widget googleWideButton() {
      final textStyle = theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface.withOpacity(0.85),
      );

      return SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);

            try {
              final userCredential = await GoogleAuth.signIn();
              final user = userCredential.user;
              
              if (user != null) {
                // Check if account is ALREADY registered
                final userDoc = await firestoreDb.collection('users').doc(user.uid).get();
                bool exists = userDoc.exists;
                
                final email = user.email;
                if (!exists && email != null && email.isNotEmpty) {
                  final emailQuery = await firestoreDb.collection('users').where('email', isEqualTo: email).limit(1).get();
                  if (emailQuery.docs.isNotEmpty) {
                    exists = true;
                  }
                }

                if (exists) {
                  await FirebaseAuth.instance.signOut();
                  throw FirebaseAuthException(
                    code: 'ACCOUNT_EXISTS',
                    message: 'Google account is already registered. Please log in.',
                  );
                }

                if (!mounted) return;
                setState(() {
                  _isGoogleSignup = true;
                  _googleUser = user;
                  if (user.displayName != null) {
                    _fullNameController.text = user.displayName!;
                  }
                  if (user.email != null) {
                    _emailController.text = user.email!;
                  }
                  _googlePhotoUrl = user.photoURL;
                });
                
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please confirm your details to complete sign up.')),
                );
              }
            } on FirebaseAuthException catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(e.message ?? 'Google sign-in failed (${e.code})')),
              );
            } catch (_) {
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Google sign-in failed')),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: scheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: chrome.mutedColor.withOpacity(0.18)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chrome.mutedColor.withOpacity(0.12),
                ),
                child: Text(
                  'G',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface.withOpacity(0.90),
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Continue with Google',
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final background =
        isLight ? Theme.of(context).scaffoldBackgroundColor : chrome.frameColor;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: visual.neumorphism
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
                          ],
                    border: Border.all(
                      color: chrome.mutedColor
                          .withOpacity(visual.neumorphism ? 0.14 : 0.10),
                      width: 1,
                    ),
                  ),
                  child: Form(
                    key: _formKey,
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
                            'Sign up',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const AppModeSelector(
                            padding: EdgeInsets.only(bottom: 12),
                          ),
                          GestureDetector(
                            onTap: () async {
                              if (_profileImageBytes == null) {
                                await _showProfileImageOptions();
                                return;
                              }
                              await _openProfileImageEditor(
                                bytes: _profileImageBytes!,
                                initialAlignment: _profileImageAlignment,
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: chrome.mutedColor.withOpacity(0.12),
                                    border: Border.all(
                                        color: chrome.surfaceColor, width: 3),
                                  ),
                                  child: ClipOval(
                                    child: _profileImageBytes == null
                                        ? (_googlePhotoUrl != null 
                                            ? Image.network(
                                                _googlePhotoUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.person_outline,
                                                color: scheme.onSurface
                                                    .withOpacity(0.65),
                                                size: 40,
                                              ))
                                        : Image.memory(
                                            _profileImageBytes!,
                                            fit: BoxFit.cover,
                                            alignment: _profileImageAlignment,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: chrome.accentBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: chrome.surfaceColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_profileImageBytes != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Tap photo to adjust alignment',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          _SignupField(
                            labelText: 'Full name',
                            hintText: 'Your full name',
                            controller: _fullNameController,
                          ),
                          const SizedBox(height: 14),
                          _SignupField(
                            labelText: 'Profession',
                            hintText: 'Your profession',
                            controller: _professionController,
                          ),
                          const SizedBox(height: 14),
                          _SignupField(
                            labelText: 'Email',
                            hintText: 'Your email',
                            controller: _emailController,
                            readOnly: _isGoogleSignup,
                            validator: (value) {
                              final v = (value ?? '').trim();
                              if (v.isEmpty) return 'Required';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v)) {
                                return 'Enter valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          if (!_isGoogleSignup) ...[
                            _SignupField(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              controller: _passwordController,
                              obscureText: true,
                            ),
                            const SizedBox(height: 14),
                            _SignupField(
                              labelText: 'Confirm password',
                              hintText: 'Re-enter your password',
                              controller: _confirmPasswordController,
                              obscureText: true,
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) return 'Required';
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Checkbox(
                                value: _acceptTerms,
                                onChanged: (v) =>
                                    setState(() => _acceptTerms = v ?? false),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'I accept the terms and privacy policy',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _acceptTerms ? _onFinishRegistration : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: chrome.textColor,
                                foregroundColor: chrome.surfaceColor,
                                disabledBackgroundColor:
                                    chrome.textColor.withOpacity(0.35),
                                disabledForegroundColor:
                                    chrome.surfaceColor.withOpacity(0.75),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Sign up'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_isGoogleSignup) ...[
                            Text(
                              'Or register with',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: googleWideButton(),
                            ),
                            const SizedBox(height: 14),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => Navigator.of(context).maybePop(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 4),
                                  child: Text(
                                    'Log in',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ProfileImageAction { camera, gallery }

class _SignupProfileEditorResult {
  const _SignupProfileEditorResult({
    required this.bytes,
    required this.alignment,
  });

  final Uint8List bytes;
  final Alignment alignment;
}

class _SignupProfileEditorScreen extends StatefulWidget {
  const _SignupProfileEditorScreen({
    required this.initialBytes,
    required this.initialAlignment,
  });

  final Uint8List initialBytes;
  final Alignment initialAlignment;

  @override
  State<_SignupProfileEditorScreen> createState() =>
      _SignupProfileEditorScreenState();
}

class _SignupProfileEditorScreenState
    extends State<_SignupProfileEditorScreen> {
  late Uint8List _bytes;
  late double _x;
  late double _y;

  Alignment get _alignment => Alignment(_x, _y);

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
    _x = widget.initialAlignment.x;
    _y = widget.initialAlignment.y;
  }

  void _updateAlignmentFromDrag(DragUpdateDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final nextX = (_x + (details.delta.dx / (size.width / 2.3)))
        .clamp(-1.0, 1.0)
        .toDouble();
    final nextY = (_y + (details.delta.dy / (size.height / 2.3)))
        .clamp(-1.0, 1.0)
        .toDouble();

    setState(() {
      _x = nextX;
      _y = nextY;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    final onFrame = ThemeData.estimateBrightnessForColor(chrome.frameColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: onFrame),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _SignupProfileEditorResult(
                          bytes: _bytes,
                          alignment: _alignment,
                        ),
                      );
                    },
                    child: Text(
                      'Done',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: chrome.accentBlue,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final diameter = (constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight) *
                      0.86;

                  return Center(
                    child: SizedBox.square(
                      dimension: diameter,
                      child: GestureDetector(
                        onPanUpdate: (d) => _updateAlignmentFromDrag(
                            d, Size(diameter, diameter)),
                        child: ClipOval(
                          child: Image.memory(
                            _bytes,
                            fit: BoxFit.cover,
                            alignment: _alignment,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Drag to align your profile photo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onFrame.withOpacity(0.86),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupField extends StatelessWidget {
  const _SignupField({
    required this.labelText,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.readOnly = false,
    this.validator,
  });

  final String labelText;
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final bool readOnly;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chrome = AppChromeTheme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurface.withOpacity(0.70),
      fontWeight: FontWeight.w600,
    );
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withOpacity(0.45),
      fontWeight: FontWeight.w400,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelText, style: labelStyle),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            readOnly: readOnly,
            validator: validator ??
                (value) {
                  if ((value ?? '').trim().isEmpty) return 'Required';
                  return null;
                },
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: hintStyle,
              filled: true,
              fillColor: chrome.mutedColor.withOpacity(0.08),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: chrome.mutedColor.withOpacity(0.22),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: chrome.mutedColor.withOpacity(0.18),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 1.2),
              ),
              errorStyle: const TextStyle(height: 0.001),
            ),
          ),
        ),
      ],
    );
  }
}
