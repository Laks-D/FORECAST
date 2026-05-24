import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:typed_data';

import '../../calendar/bloc/calendar_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import 'widgets/dashboard_phone_frame.dart';
import '../../join_request/ui/join_request_banner.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.initialUserName,
    this.initialUserEmail,
    this.initialUserPhone,
    this.initialUserAvatarBytes,
    this.initialUserAvatarAlignment,
    this.canSwitchMode = false,
  });

  final String? initialUserName;
  final String? initialUserEmail;
  final String? initialUserPhone;
  final Uint8List? initialUserAvatarBytes;
  final Alignment? initialUserAvatarAlignment;
  /// When true the user is enrolled as both a student and a tutor;
  /// the UI exposes a mode-switch option so they can toggle roles.
  final bool canSwitchMode;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = DashboardCubit();
            // Load persisted profile, then overlay any initial values.
            cubit.loadProfile().then((_) {
              final name = (initialUserName ?? '').trim();
              final email = (initialUserEmail ?? '').trim();
              final phone = (initialUserPhone ?? '').trim();
              final avatarBytes = initialUserAvatarBytes;
              final avatarAlignment = initialUserAvatarAlignment;
              if (name.isNotEmpty) cubit.setUserName(name);
              if (email.isNotEmpty) cubit.setUserEmail(email);
              if (phone.isNotEmpty) cubit.setUserPhone(phone);
              if (avatarBytes != null) cubit.setUserAvatarBytes(avatarBytes);
              if (avatarAlignment != null) cubit.setUserAvatarAlignment(avatarAlignment);
            });
            return cubit;
          },
        ),
        BlocProvider(create: (_) => CalendarCubit()),
      ],
      child: _DashboardView(canSwitchMode: canSwitchMode),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({this.canSwitchMode = false});

  final bool canSwitchMode;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: JoinRequestBanner(
        child: const DashboardPhoneFrame(),
      ),
    );
  }
}
