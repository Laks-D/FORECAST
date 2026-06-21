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
      _nationalityCtrl.text = _signupProfile?.nationality ?? 'India';
      _currencyCtrl.text = _signupProfile?.currency ?? '...';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _handleCtrl.dispose(); _middleNameCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose();
    _nationalityCtrl.dispose(); _currencyCtrl.dispose();
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
      context.read<DashboardCubit>().updateProfile(
        name: _nameCtrl.text, handle: _handleCtrl.text,
        middleName: _middleNameCtrl.text, phone: _phoneCtrl.text,
        email: _emailCtrl.text, gender: _selectedGender, dob: _selectedDob,
      );
      final updatedProfile = (_signupProfile ?? SignupProfileData(
        fullName: _nameCtrl.text.trim(), userName: _handleCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      )).copyWith(
        nationality: _nationalityCtrl.text.trim(),
        currency: _currencyCtrl.text.trim(),
      );
      await SignupProfileStorage.saveProfile(updatedProfile);
      if (!mounted) return;
      setState(() { _signupProfile = updatedProfile; });
      try { profileCubit.refresh(); } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Profile saved', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    }
    setState(() => _editing = !_editing);
  }

  void _openProfilePhoto(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(value: cubit, child: const ProfilePhotoScreen()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F2F8),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, isDark),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _SectionLabel('PERSONAL INFORMATION', isDark),
              _GlassCard(isDark: isDark, children: [
                _InfoRow(icon: Icons.person_rounded, label: 'Full Name',
                  value: _editing ? null : _nameCtrl.text,
                  controller: _editing ? _nameCtrl : null,
                  accent: const Color(0xFF6C63FF), isDark: isDark),
                _InfoRow(icon: Icons.alternate_email_rounded, label: 'Username',
                  value: _editing ? null : _handleCtrl.text,
                  controller: _editing ? _handleCtrl : null,
                  accent: const Color(0xFF06B6D4), isDark: isDark),
                _InfoRow(icon: Icons.mail_rounded, label: 'Email',
                  value: _editing ? null : _emailCtrl.text,
                  controller: _editing ? _emailCtrl : null,
                  accent: const Color(0xFFEC4899), isDark: isDark, isLast: true),
              ]),
              _SectionLabel('CONTACT & LOCATION', isDark),
              _GlassCard(isDark: isDark, children: [
                _InfoRow(icon: Icons.phone_rounded, label: 'Phone',
                  value: _editing ? null : (_phoneCtrl.text.isEmpty ? 'Not set' : _phoneCtrl.text),
                  controller: _editing ? _phoneCtrl : null,
                  accent: const Color(0xFFF59E0B), isDark: isDark),
                _InfoRow(icon: Icons.public_rounded, label: 'Nationality',
                  value: _editing ? null : _nationalityCtrl.text,
                  controller: _editing ? _nationalityCtrl : null,
                  accent: const Color(0xFF10B981), isDark: isDark, isLast: true),
              ]),
              _SectionLabel('PREFERENCES', isDark),
              _GlassCard(isDark: isDark, children: [
                _InfoRow(icon: Icons.payments_rounded, label: 'Currency',
                  value: _editing ? null : _currencyCtrl.text,
                  controller: _editing ? _currencyCtrl : null,
                  accent: const Color(0xFF6C63FF), isDark: isDark),
                _InfoRow(icon: Icons.wc_rounded, label: 'Gender',
                  value: _editing ? null : (_selectedGender ?? 'Not set'),
                  accent: const Color(0xFF8B5CF6), isDark: isDark,
                  trailing: _editing ? _GenderDropdown(value: _selectedGender,
                    onChanged: (v) => setState(() => _selectedGender = v), isDark: isDark) : null),
                _InfoRow(icon: Icons.cake_rounded, label: 'Date of Birth',
                  value: _editing ? null : (_selectedDob != null ? AppDateUtils.displayDate(_selectedDob!) : 'Not set'),
                  accent: const Color(0xFFF59E0B), isDark: isDark, isLast: true,
                  trailing: _editing ? _DobPicker(value: _selectedDob,
                    onChanged: (v) => setState(() => _selectedDob = v), isDark: isDark) : null),
              ]),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final name = state.userName ?? 'User';
        final handle = state.userHandle ?? '';
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: isDark
                ? [const Color(0xFF1A1035), const Color(0xFF0D1B3E)]
                : [const Color(0xFF6C63FF), const Color(0xFF4F46E5)],
            ),
          ),
          child: SafeArea(bottom: false, child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('My Profile', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                TextButton(
                  onPressed: _toggleEdit,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_editing ? Icons.check_rounded : Icons.edit_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(_editing ? 'Save' : 'Edit',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              key: const Key('profile_avatar_tap'),
              onTap: () => _openProfilePhoto(context),
              child: Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: ClipOval(child: state.userAvatarBytes == null
                    ? Container(
                        decoration: BoxDecoration(gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.06)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        )),
                        child: const Icon(Icons.person_rounded, size: 52, color: Colors.white70))
                    : Image.memory(state.userAvatarBytes!, fit: BoxFit.cover, alignment: state.userAvatarAlignment)),
                ),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
            if (handle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('@', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 24),
          ])),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title, this.isDark);
  final String title; final bool isDark;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
    child: Text(title, style: TextStyle(
      color: isDark ? Colors.white38 : Colors.black38,
      fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2)),
  );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.children, required this.isDark});
  final List<Widget> children; final bool isDark;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.07), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon, required this.label, required this.accent, required this.isDark,
    this.value, this.controller, this.trailing, this.isLast = false,
  });
  final IconData icon; final String label; final Color accent; final bool isDark;
  final String? value; final TextEditingController? controller; final Widget? trailing; final bool isLast;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? Colors.white38 : Colors.black38;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.06);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 14),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: trailing != null
            ? Align(alignment: Alignment.centerRight, child: trailing!)
            : controller != null
              ? TextField(
                  controller: controller, textAlign: TextAlign.right, cursorColor: accent,
                  style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true, border: InputBorder.none, enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ))
              : Text(value ?? '—', textAlign: TextAlign.right, style: TextStyle(
                  color: (value == null || value == 'Not set' || value!.isEmpty) ? labelColor : valueColor,
                  fontWeight: FontWeight.w700, fontSize: 14))),
        ]),
      ),
      if (!isLast) Divider(height: 1, indent: 68, endIndent: 16, color: dividerColor),
    ]);
  }
}

class _GenderDropdown extends StatelessWidget {
  const _GenderDropdown({required this.value, required this.onChanged, required this.isDark});
  final String? value; final ValueChanged<String?> onChanged; final bool isDark;
  @override
  Widget build(BuildContext context) {
    const options = ['Male', 'Female', 'Other', 'Prefer not to say'];
    return DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: options.contains(value) ? value : null, isDense: true,
      dropdownColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 14),
      items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
    ));
  }
}

class _DobPicker extends StatelessWidget {
  const _DobPicker({required this.value, required this.onChanged, required this.isDark});
  final DateTime? value; final ValueChanged<DateTime?> onChanged; final bool isDark;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(
              primary: const Color(0xFF6C63FF), onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF1C1C2E) : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black,
            ), textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C63FF)))),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value != null ? AppDateUtils.displayDate(value!) : 'Select',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 4),
        Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black38),
      ]),
    );
  }
}

extension SignupProfileDataExt on SignupProfileData {
  SignupProfileData copyWith({
    String? fullName, String? profession, String? userName, String? email,
    String? nationality, String? currency, List<String>? selectedPrograms, List<String>? preferences,
  }) {
    return SignupProfileData(
      fullName: fullName ?? this.fullName, profession: profession ?? this.profession,
      userName: userName ?? this.userName, email: email ?? this.email,
      nationality: nationality ?? this.nationality, currency: currency ?? this.currency,
      selectedPrograms: selectedPrograms ?? this.selectedPrograms,
      preferences: preferences ?? this.preferences,
    );
  }
}
