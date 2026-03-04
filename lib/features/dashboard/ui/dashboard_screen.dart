import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:typed_data';

import '../../../core/services/notification_cubit.dart';
import '../../calendar/bloc/calendar_cubit.dart';
import '../../calendar/bloc/sessions_cubit.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_state.dart';
import '../../../design_system/theme/app_chrome_theme.dart';
import '../bloc/dashboard_cubit.dart';
import 'widgets/dashboard_phone_frame.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.initialUserName,
    this.initialUserEmail,
    this.initialUserPhone,
    this.initialUserAvatarBytes,
    this.initialUserAvatarAlignment,
  });

  final String? initialUserName;
  final String? initialUserEmail;
  final String? initialUserPhone;
  final Uint8List? initialUserAvatarBytes;
  final Alignment? initialUserAvatarAlignment;

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
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final chrome = AppChromeTheme.of(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<SessionsCubit, SessionsState>(
          listenWhen: (prev, next) =>
              !next.isLoading && prev.sessions != next.sessions,
          listener: (context, state) {
            context
                .read<NotificationCubit>()
                .scheduleSessionReminders(state.sessions);
          },
        ),
        BlocListener<ClientBloc, ClientState>(
          listenWhen: (prev, next) =>
              next is ClientLoaded &&
              (prev is! ClientLoaded ||
                  prev.entities != (next).entities),
          listener: (context, state) {
            if (state is ClientLoaded) {
              context
                  .read<NotificationCubit>()
                  .schedulePaymentReminders(state.entities);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: chrome.frameColor,
        body: const DashboardPhoneFrame(),
      ),
    );
  }
}
