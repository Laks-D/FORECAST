import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/student_onboarding_bloc.dart';
import '../bloc/student_onboarding_event.dart';
import '../bloc/student_onboarding_state.dart';

/// Old Money aesthetic colors
class _OldMoneyColors {
  static const Color ivory = Color(0xFFF5F5F0);
  static const Color forestGreen = Color(0xFF2D5A27);
  static const Color darkText = Color(0xFF3D3D3D);
  static const Color lightGold = Color(0xFFD4A574);
  static const Color errorRed = Color(0xFFC41E3A);
}

/// Student Onboarding Screen for joining a class via invitation link.
///
/// This screen is shown to non-signed-in users when they click on an
/// onboarding link. It allows them to provide their details and join
/// a class without authentication.
class StudentOnboardingScreen extends StatefulWidget {
  /// The organization ID for the class they're joining
  final String orgId;

  const StudentOnboardingScreen({
    super.key,
    required this.orgId,
  });

  @override
  State<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _professionController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _professionController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<StudentOnboardingBloc>().add(
            SubmitStudentFormEvent(
              orgId: widget.orgId,
              fullName: _fullNameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              profession: _professionController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StudentOnboardingBloc(),
      child: BlocListener<StudentOnboardingBloc, StudentOnboardingState>(
        listener: (context, state) {
          if (state.status == StudentOnboardingStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: _OldMoneyColors.errorRed,
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: _OldMoneyColors.ivory,
          body: SafeArea(
            child: BlocBuilder<StudentOnboardingBloc, StudentOnboardingState>(
              builder: (context, state) {
                // Show success screen
                if (state.status == StudentOnboardingStatus.success) {
                  return _SuccessView(studentName: state.studentName ?? '');
                }

                // Show form
                return _FormView(
                  formKey: _formKey,
                  fullNameController: _fullNameController,
                  phoneController: _phoneController,
                  professionController: _professionController,
                  isLoading:
                      state.status == StudentOnboardingStatus.loading,
                  onSubmit: () => _submitForm(context),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Form view for entering student details
class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController professionController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
    required this.professionController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Join Your Class',
            style: GoogleFonts.playfairDisplay(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: _OldMoneyColors.darkText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your details to get started',
            style: GoogleFonts.lora(
              fontSize: 16,
              color: _OldMoneyColors.darkText.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 40),

          // Form
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name Field
                _FormField(
                  label: 'Full Name',
                  controller: fullNameController,
                  hint: 'e.g., John Doe',
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Phone Number Field
                _FormField(
                  label: 'Phone Number',
                  controller: phoneController,
                  hint: 'e.g., +1 (555) 123-4567',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.replaceAll(RegExp(r'\D'), '').length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Profession Field
                _FormField(
                  label: 'Profession',
                  controller: professionController,
                  hint: 'e.g., Software Engineer',
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your profession';
                    }
                    if (value.length < 2) {
                      return 'Profession must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Join Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _OldMoneyColors.forestGreen,
                disabledBackgroundColor:
                    _OldMoneyColors.forestGreen.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _OldMoneyColors.ivory,
                        ),
                      ),
                    )
                  : Text(
                      'Join Class',
                      style: GoogleFonts.lora(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _OldMoneyColors.ivory,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable form field widget
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _OldMoneyColors.darkText,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.lora(
              fontSize: 14,
              color: _OldMoneyColors.darkText.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _OldMoneyColors.lightGold.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _OldMoneyColors.lightGold.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _OldMoneyColors.lightGold,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _OldMoneyColors.errorRed,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: _OldMoneyColors.errorRed,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: GoogleFonts.lora(
            fontSize: 14,
            color: _OldMoneyColors.darkText,
          ),
        ),
      ],
    );
  }
}

/// Success view shown after successful onboarding
class _SuccessView extends StatelessWidget {
  final String studentName;

  const _SuccessView({required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success Checkmark
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _OldMoneyColors.forestGreen.withOpacity(0.1),
                border: Border.all(
                  color: _OldMoneyColors.forestGreen,
                  width: 3,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 64,
                  color: _OldMoneyColors.forestGreen,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Success Message
            Text(
              'Welcome!',
              style: GoogleFonts.playfairDisplay(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: _OldMoneyColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You have successfully joined the class!',
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 18,
                color: _OldMoneyColors.darkText.withOpacity(0.8),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your instructor will be in touch soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 14,
                color: _OldMoneyColors.darkText.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
