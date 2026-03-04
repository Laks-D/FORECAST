import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final _middleNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
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
      _middleNameCtrl.text = st.userMiddleName ?? '';
      _phoneCtrl.text = st.userPhone ?? '';
      _emailCtrl.text = st.userEmail ?? '';
      _selectedGender = st.userGender;
      _selectedDob = st.userDateOfBirth;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _middleNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSignupProfile() async {
    final profile = await SignupProfileStorage.getProfile();
    if (!mounted) return;
    setState(() => _signupProfile = profile);
  }

  static const _cardRadius = 40.0;

  void _toggleEdit() {
    if (_editing) {
      // Save
      final cubit = context.read<DashboardCubit>();
      cubit.setUserName(_nameCtrl.text.trim());
      cubit.setUserMiddleName(_middleNameCtrl.text.trim());
      cubit.setUserPhone(_phoneCtrl.text.trim());
      cubit.setUserEmail(_emailCtrl.text.trim());
      if (_selectedGender != null) cubit.setUserGender(_selectedGender!);
      if (_selectedDob != null) cubit.setUserDateOfBirth(_selectedDob!);
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
      appBar: AppBar(
        backgroundColor: chrome.frameColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _toggleEdit,
            child: Text(
              _editing ? 'Save' : 'Edit Profile',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.surfaceColor,
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_cardRadius),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: BlocBuilder<DashboardCubit, DashboardState>(
                        buildWhen: (p, n) =>
                            p.userAvatarBytes != n.userAvatarBytes ||
                            p.userAvatarAlignment != n.userAvatarAlignment,
                        builder: (context, state) {
                          final avatarBytes = state.userAvatarBytes;
                          return Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              key: const Key('profile_avatar_tap'),
                              onTap: () => _openProfilePhoto(context),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 148,
                                height: 148,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: chrome.mutedColor.withOpacity(0.22),
                                ),
                                child: ClipOval(
                                  child: avatarBytes == null
                                      ? Center(
                                          child: Icon(
                                            Icons.person_outline,
                                            size: 56,
                                            color: chrome.mutedColor.withOpacity(0.7),
                                          ),
                                        )
                                      : Image.memory(
                                          avatarBytes,
                                          fit: BoxFit.cover,
                                          alignment: state.userAvatarAlignment,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: BlocBuilder<DashboardCubit, DashboardState>(
                        buildWhen: (p, n) =>
                            p.userName != n.userName ||
                            p.userMiddleName != n.userMiddleName ||
                            p.userEmail != n.userEmail ||
                            p.userPhone != n.userPhone ||
                            p.userGender != n.userGender ||
                            p.userDateOfBirth != n.userDateOfBirth,
                        builder: (context, state) {
                          final name = (state.userName ?? 'User').trim();
                          final middleName = (state.userMiddleName ?? '').trim();
                          final email = (state.userEmail ?? '').trim();
                          final phone = (state.userPhone ?? '').trim();
                          final gender = (state.userGender ?? '').trim();
                          final dob = state.userDateOfBirth;
                          final userName = (_signupProfile?.userName ?? '').trim();
                          final profession = (_signupProfile?.profession ?? '').trim();
                          final programs = _signupProfile?.selectedPrograms ?? const <String>[];
                          final preferences = _signupProfile?.preferences ?? const <String>[];

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _editing
                                  ? _EditField(
                                      controller: _nameCtrl,
                                      icon: Icons.person_outline,
                                      label: 'Name',
                                    )
                                  : _InfoPill(
                                      icon: Icons.person_outline,
                                      label: 'Name',
                                      value: name.isEmpty ? 'User' : name,
                                    ),
                              const SizedBox(height: 14),
                              _editing
                                  ? _EditField(
                                      controller: _middleNameCtrl,
                                      icon: Icons.person_outline,
                                      label: 'Middle name',
                                    )
                                  : _InfoPill(
                                      icon: Icons.person_outline,
                                      label: 'Middle name',
                                      value: middleName.isEmpty ? 'Not set' : middleName,
                                    ),
                              const SizedBox(height: 14),
                              _editing
                                  ? _EditField(
                                      controller: _phoneCtrl,
                                      icon: Icons.phone_outlined,
                                      label: 'Phone number',
                                      keyboardType: TextInputType.phone,
                                    )
                                  : _InfoPill(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone number',
                                      value: phone.isEmpty ? 'Not set' : phone,
                                    ),
                              const SizedBox(height: 14),
                              _editing
                                  ? _EditField(
                                      controller: _emailCtrl,
                                      icon: Icons.email_outlined,
                                      label: 'Email address',
                                      keyboardType: TextInputType.emailAddress,
                                    )
                                  : _InfoPill(
                                      icon: Icons.email_outlined,
                                      label: 'Email address',
                                      value: email.isEmpty ? 'Not set' : email,
                                    ),
                              const SizedBox(height: 14),
                              _editing
                                  ? _GenderPicker(
                                      value: _selectedGender,
                                      onChanged: (v) => setState(() => _selectedGender = v),
                                    )
                                  : _InfoPill(
                                      icon: Icons.wc_outlined,
                                      label: 'Gender',
                                      value: gender.isEmpty ? 'Not set' : gender,
                                    ),
                              const SizedBox(height: 14),
                              _editing
                                  ? _DobPicker(
                                      value: _selectedDob,
                                      onChanged: (v) => setState(() => _selectedDob = v),
                                    )
                                  : _InfoPill(
                                      icon: Icons.cake_outlined,
                                      label: 'Date of birth',
                                      value: dob != null
                                          ? AppDateUtils.displayDate(dob)
                                          : 'Not set',
                                    ),
                              if (userName.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _InfoPill(
                                  icon: Icons.alternate_email,
                                  label: 'Username',
                                  value: userName,
                                ),
                              ],
                              if (profession.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _InfoPill(
                                  icon: Icons.work_outline,
                                  label: 'Profession',
                                  value: profession,
                                ),
                              ],
                              if (programs.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _InfoPill(
                                  icon: Icons.menu_book_outlined,
                                  label: 'Selected programs',
                                  value: programs.join(', '),
                                ),
                              ],
                              if (preferences.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _InfoPill(
                                  icon: Icons.tune_outlined,
                                  label: 'Preferences',
                                  value: preferences.join(', '),
                                ),
                              ],
                            ],
                          );
                        },
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.mutedColor,
          fontWeight: FontWeight.w700,
        );

    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: chrome.textColor,
          fontWeight: FontWeight.w800,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chrome.mutedColor.withOpacity(0.18),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, color: Colors.black87, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(value, style: valueStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.mutedColor,
          fontWeight: FontWeight.w700,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chrome.mutedColor.withOpacity(0.18),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, color: Colors.black87, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: chrome.textColor,
                            fontWeight: FontWeight.w800,
                          ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/* ─────────────── Gender Picker (edit mode) ─────────────── */

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.mutedColor,
          fontWeight: FontWeight.w700,
        );

    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: chrome.textColor,
          fontWeight: FontWeight.w800,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chrome.mutedColor.withOpacity(0.18),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.wc_outlined, color: Colors.black87, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gender', style: labelStyle, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    DropdownButton<String>(
                      value: _options.contains(value) ? value : null,
                      hint: Text('Select', style: valueStyle),
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      style: valueStyle,
                      items: _options
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: onChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────── Date-of-Birth Picker (edit mode) ─────────────── */

class _DobPicker extends StatelessWidget {
  const _DobPicker({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chrome.mutedColor,
          fontWeight: FontWeight.w700,
        );

    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: chrome.textColor,
          fontWeight: FontWeight.w800,
        );

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000),
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 66),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chrome.mutedColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.cake_outlined, color: Colors.black87, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date of birth', style: labelStyle, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        value != null
                            ? AppDateUtils.displayDate(value!)
                            : 'Tap to select',
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}