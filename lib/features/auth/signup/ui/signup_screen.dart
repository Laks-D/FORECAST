import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/username_key.dart';
import '../../../../core/firebase/firestore_db.dart';
import '../../../../core/storage/signup_profile_storage.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _professionController = TextEditingController();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Uint8List? _profileImageBytes;
  double _profileAlignX = 0;
  double _profileAlignY = 0;

  Alignment get _profileImageAlignment => Alignment(_profileAlignX, _profileAlignY);

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
                onTap: () => Navigator.of(context).pop(ProfileImageAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(ProfileImageAction.gallery),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    final source = action == ProfileImageAction.camera ? ImageSource.camera : ImageSource.gallery;
    await _pickProfileImage(source);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _professionController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onFinishRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    final usernameRaw = _userNameController.text.trim();
    final usernameKey = usernameKeyFromInput(usernameRaw);
    if (usernameKey.isEmpty || usernameKey.length < 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be at least 3 characters')),
      );
      return;
    }

    // Create Firebase user first (source of truth for identity).
    // If the email already exists, fall back to sign-in so the user isn't blocked.
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        // Reserve username key -> uid/email mapping for username-based login.
        try {
          await firestoreDb.runTransaction((tx) async {
            final usernameRef = firestoreDb.collection('usernames').doc(usernameKey);
            final existing = await tx.get(usernameRef);
            if (existing.exists) {
              throw StateError('USERNAME_TAKEN');
            }
            tx.set(usernameRef, {
              'uid': uid,
              'email': email,
              'username': usernameRaw,
              'createdAt': FieldValue.serverTimestamp(),
            });

            final userRef = firestoreDb.collection('users').doc(uid);
            tx.set(
              userRef,
              {
                'fullName': _fullNameController.text.trim(),
                'profession': _professionController.text.trim(),
                'userName': usernameRaw,
                'userNameKey': usernameKey,
                'email': email,
                'createdAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          });
        } on StateError catch (e) {
          if (e.message == 'USERNAME_TAKEN') {
            // Clean up newly-created auth user if we couldn't reserve the username.
            try {
              await credential.user?.delete();
              await FirebaseAuth.instance.signOut();
            } catch (_) {
              // Ignore cleanup failures.
            }
            throw FirebaseAuthException(
              code: 'USERNAME_TAKEN',
              message: 'Username already taken. Please choose another one.',
            );
          }
          rethrow;
        } on FirebaseException catch (e) {
          // Convert Firestore failures into a user-facing message.
          try {
            await credential.user?.delete();
            await FirebaseAuth.instance.signOut();
          } catch (_) {
            // Ignore cleanup failures.
          }

          final message = switch (e.code) {
            'permission-denied' => 'Database permission denied. Update Firestore rules.',
            'unavailable' => 'No internet connection (Firestore client is offline).',
            _ => (e.message ?? 'Database error (${e.code})'),
          };
          throw FirebaseAuthException(code: 'FIRESTORE_ERROR', message: message);
        } catch (_) {
          // Unknown failure reserving username/profile; avoid orphaned auth users.
          try {
            await credential.user?.delete();
            await FirebaseAuth.instance.signOut();
          } catch (_) {
            // Ignore cleanup failures.
          }
          throw FirebaseAuthException(
            code: 'SIGNUP_INCOMPLETE',
            message: 'Signup failed while saving profile. Please try again.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account already exists — signed you in.')),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        } on FirebaseAuthException {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email already registered. Please log in or reset your password.'),
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

    final profile = SignupProfileData(
      fullName: _fullNameController.text.trim(),
      profession: _professionController.text.trim(),
      userName: _userNameController.text.trim(),
      email: email,
    );

    await SignupProfileStorage.saveProfile(profile);
    if (!mounted) return;

    // No navigation needed: LandingScreen listens to FirebaseAuth and will
    // switch to the signed-in app automatically.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.surfaceColor,
              borderRadius: BorderRadius.circular(42),
            ),
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 26, 10, 18),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          children: [                    GestureDetector(
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
                              color: const Color(0xFFD1C3C5),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child: _profileImageBytes == null
                                  ? Icon(
                                      Icons.person_outline,
                                      color: Colors.black.withOpacity(0.65),
                                      size: 40,
                                    )
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
                              decoration: const BoxDecoration(
                                color: Color(0xFF8FA4C2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_profileImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Tap photo to adjust alignment',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    _SignupField(
                      hintText: 'Full Name',
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 16),
                    _SignupField(
                      hintText: 'Profession',
                      controller: _professionController,
                    ),
                    const SizedBox(height: 16),
                    _SignupField(
                      hintText: 'Username',
                      controller: _userNameController,
                    ),
                    const SizedBox(height: 16),
                    _SignupField(
                      hintText: 'Email',
                      controller: _emailController,
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Required';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                          return 'Enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _SignupField(
                      hintText: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    _SignupField(
                      hintText: 'Confirm Password',
                      controller: _confirmPasswordController,
                      obscureText: true,
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) return 'Required';
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 198,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _onFinishRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8FA4C2),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Finish registration',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, color: Colors.black87, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
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
  State<_SignupProfileEditorScreen> createState() => _SignupProfileEditorScreenState();
}

class _SignupProfileEditorScreenState extends State<_SignupProfileEditorScreen> {
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

    final nextX = (_x + (details.delta.dx / (size.width / 2.3))).clamp(-1.0, 1.0).toDouble();
    final nextY = (_y + (details.delta.dy / (size.height / 2.3))).clamp(-1.0, 1.0).toDouble();

    setState(() {
      _x = nextX;
      _y = nextY;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
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
                        onPanUpdate: (d) => _updateAlignmentFromDrag(d, Size(diameter, diameter)),
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
                      color: Colors.white.withOpacity(0.86),
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
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.validator,
  });

  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final hintStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Colors.black.withOpacity(0.78),
          fontWeight: FontWeight.w500,
        );

    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator ??
            (value) {
              if ((value ?? '').trim().isEmpty) return 'Required';
              return null;
            },
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: hintStyle,
          filled: true,
          fillColor: const Color(0xFFD1C3C5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(16),
          ),
          errorStyle: const TextStyle(height: 0.001),
        ),
      ),
    );
  }
}
