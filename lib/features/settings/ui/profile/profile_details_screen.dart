import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/profile/user_profile_cubit.dart';
import '../../../../core/storage/signup_profile_storage.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/theme/app_chrome_theme.dart';
import '../../../dashboard/bloc/dashboard_cubit.dart';
import '../../../dashboard/bloc/dashboard_state.dart';
import 'profile_photo_screen.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  SignupProfileData? _signupProfile;
  bool _editing = false;

  final _nameCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDob;
  bool _controllersSeeded = false;

  @override
  void initState() {
    super.initState();
    _loadSignupProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersSeeded) {
      _controllersSeeded = true;
      final st = context.read<DashboardCubit>().state;
      _nameCtrl.text = st.userName ?? 'User';
      _handleCtrl.text = st.userHandle ?? 'user_123';
      _middleNameCtrl.text = st.userMiddleName ?? '';
      _phoneCtrl.text = st.userPhone ?? '';
      _emailCtrl.text = st.userEmail ?? '';
      _selectedGender = st.userGender;
      _selectedDob = st.userDateOfBirth;
      
      // Seed from SignupProfile if available
      _nationalityCtrl.text = _signupProfile?.nationality ?? 'India';
      _currencyCtrl.text = _signupProfile?.currency ?? '₹';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _handleCtrl.dispose();
    _middleNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _nationalityCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSignupProfile() async {
    final profile = await SignupProfileStorage.getProfile();
    if (!mounted) return;
    setState(() {
      _signupProfile = profile;
      if (profile != null) {
        _nationalityCtrl.text = profile.nationality;
        _currencyCtrl.text = profile.currency;
      }
    });
  }

  Future<void> _toggleEdit() async {
    if (_editing) {
      final profileCubit = context.read<UserProfileCubit>();

      // Save all fields via bulk update
      context.read<DashboardCubit>().updateProfile(
            name: _nameCtrl.text,
            handle: _handleCtrl.text,
            middleName: _middleNameCtrl.text,
            phone: _phoneCtrl.text,
            email: _emailCtrl.text,
            gender: _selectedGender,
            dob: _selectedDob,
          );

      // Save to Storage (Nationality/Currency)
      final updatedProfile = (_signupProfile ??
              SignupProfileData(
                fullName: _nameCtrl.text.trim(),
                userName: _handleCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
              ))
          .copyWith(
        nationality: _nationalityCtrl.text.trim(),
        currency: _currencyCtrl.text.trim(),
      );

      await SignupProfileStorage.saveProfile(updatedProfile);
      if (!mounted) return;

      setState(() {
        _signupProfile = updatedProfile;
      });

      // Propagate new default currency across app.
      try {
        profileCubit.refresh();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Profile saved', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    setState(() => _editing = !_editing);
  }

  void _openProfilePhoto(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const ProfilePhotoScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return Scaffold(
      backgroundColor: chrome.frameColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: chrome.mutedColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Avatar with Neon Glow
            Center(
              child: BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Neon Glow
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: VibrantColors.softPink.withOpacity(0.22),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        key: const Key('profile_avatar_tap'),
                        onTap: () => _openProfilePhoto(context),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: VibrantColors.softPink, width: 2),
                          ),
                          child: ClipOval(
                            child: state.userAvatarBytes == null
                                ? Container(
                                    color: chrome.surfaceColor,
                                    child: Icon(Icons.person, size: 60, color: chrome.mutedColor),
                                  )
                                : Image.memory(
                                    state.userAvatarBytes!,
                                    fit: BoxFit.cover,
                                    alignment: state.userAvatarAlignment,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Personal Information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _toggleEdit();
                    },
                    child: Row(
                      children: [
                        Icon(
                          _editing ? Icons.check : Icons.edit_outlined,
                          size: 16,
                          color: chrome.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _editing ? 'SAVE' : 'Edit',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: chrome.accentBlue,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProfileSection(
              children: [
                _ProfileRow(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: _editing ? null : _nameCtrl.text,
                  controller: _editing ? _nameCtrl : null,
                  iconColor: chrome.accentBlue,
                ),
                _ProfileRow(
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: _editing ? null : _handleCtrl.text,
                  controller: _editing ? _handleCtrl : null,
                  iconColor: chrome.accentBlue,
                ),
                _ProfileRow(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: _editing ? null : _emailCtrl.text,
                  controller: _editing ? _emailCtrl : null,
                  iconColor: VibrantColors.softPink,
                ),
                _ProfileRow(
                  icon: Icons.phone_iphone_outlined,
                  label: 'Phone',
                  value: _editing ? null : _phoneCtrl.text,
                  controller: _editing ? _phoneCtrl : null,
                  iconColor: VibrantColors.warmYellow,
                ),
                _ProfileRow(
                  icon: Icons.public_outlined,
                  label: 'Nationality',
                  value: _editing ? null : _nationalityCtrl.text,
                  controller: _editing ? _nationalityCtrl : null,
                  iconColor: VibrantColors.pastelGreen,
                ),
                _ProfileRow(
                  icon: Icons.payments_outlined,
                  label: 'Primary Currency',
                  value: _editing ? null : _currencyCtrl.text,
                  controller: _editing ? _currencyCtrl : null,
                  iconColor: VibrantColors.softBlue,
                ),
                _ProfileRow(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: _editing ? null : (_selectedGender ?? 'Not set'),
                  iconColor: VibrantColors.softBlue,
                  child: _editing
                      ? _GenderDropdown(
                          value: _selectedGender,
                          onChanged: (v) => setState(() => _selectedGender = v),
                        )
                      : null,
                ),
                _ProfileRow(
                  icon: Icons.cake_outlined,
                  label: 'Date of Birth',
                  value: _editing
                      ? null
                      : (_selectedDob != null
                          ? AppDateUtils.displayDate(_selectedDob!)
                          : 'Not set'),
                  iconColor: VibrantColors.warmYellow,
                  isLast: true,
                  child: _editing
                      ? _DobPickerInline(
                          value: _selectedDob,
                          onChanged: (v) => setState(() => _selectedDob = v),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 32),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: chrome.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: chrome.mutedColor.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.controller,
    required this.iconColor,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;
  final TextEditingController? controller;
  final Color iconColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              // Label
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: chrome.mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 10),
              // Value or Input
              if (child != null)
                Expanded(child: Align(alignment: Alignment.centerRight, child: child!))
              else if (controller != null)
                Expanded(
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.right,
                    cursorColor: chrome.accentBlue,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: chrome.accentBlue, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                )
              else if (value != null)
                Text(
                  value!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: chrome.mutedColor.withOpacity(0.08),
          ),
      ],
    );
  }
}

class _GenderDropdown extends StatelessWidget {
  const _GenderDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    const options = ['Male', 'Female', 'Other', 'Prefer not to say'];
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: options.contains(value) ? value : null,
        isDense: true,
        dropdownColor: const Color(0xFF1C1C1E),
        icon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.unfold_more, size: 16, color: chrome.mutedColor.withOpacity(0.5)),
        ),
        underline: const SizedBox.shrink(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
        items: options.map((s) => DropdownMenuItem(
          value: s, 
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(s),
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _DobPickerInline extends StatelessWidget {
  const _DobPickerInline({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000),
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: chrome.accentBlue, 
                onPrimary: Colors.white,
                surface: const Color(0xFF1C1C1E),
                onSurface: Colors.white
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: chrome.accentBlue),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value != null ? AppDateUtils.displayDate(value!) : 'Select Date',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.calendar_today_outlined, size: 14, color: chrome.mutedColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

extension SignupProfileDataExt on SignupProfileData {
  SignupProfileData copyWith({
    String? fullName,
    String? profession,
    String? userName,
    String? email,
    String? nationality,
    String? currency,
    List<String>? selectedPrograms,
    List<String>? preferences,
  }) {
    return SignupProfileData(
      fullName: fullName ?? this.fullName,
      profession: profession ?? this.profession,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      nationality: nationality ?? this.nationality,
      currency: currency ?? this.currency,
      selectedPrograms: selectedPrograms ?? this.selectedPrograms,
      preferences: preferences ?? this.preferences,
    );
  }
}
