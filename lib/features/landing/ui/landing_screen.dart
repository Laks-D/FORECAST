import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/login/ui/login_screen.dart';
import '../../dashboard/ui/dashboard_screen.dart';
import '../../navigation/bloc/nav_modules_cubit.dart';
import '../../calendar/bloc/sessions_cubit.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../../client/presentation/bloc/client_state.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/notification_cubit.dart';
import '../../../core/services/user_firestore_sync.dart';
import '../../theme_customization/bloc/app_theme_cubit.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  String? _pulledForUid;
  Future<void>? _pullFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          _pulledForUid = null;
          _pullFuture = null;
          return const LoginScreen();
        }

        if (_pulledForUid != user.uid) {
          _pulledForUid = user.uid;
          _pullFuture = () async {
            final themeCubit = context.read<AppThemeCubit>();
            await UserFirestoreSync.instance.pullAllToLocal(uidOverride: user.uid);
            // Re-apply theme (it was constructed before login).
            if (!mounted) return;
            await themeCubit.reloadFromStorage();
          }();
        }

        return FutureBuilder<void>(
          future: _pullFuture,
          builder: (context, pullSnap) {
            if (pullSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => NavModulesCubit()),
                BlocProvider(create: (_) => sl<SessionsCubit>()),
                BlocProvider(create: (_) => sl<ClientBloc>()..add(LoadClients())),
                BlocProvider(
                  create: (context) {
                    final cubit = NotificationCubit();
                    // Load prefs/records first; scheduling calls will be queued
                    // until loading completes.
                    unawaited(cubit.load());

                    // Keep reminders always in sync with the latest app data.
                    final sessionsCubit = context.read<SessionsCubit>();
                    final clientBloc = context.read<ClientBloc>();

                    // Seed initial values.
                    if (!sessionsCubit.state.isLoading) {
                      unawaited(cubit.scheduleSessionReminders(sessionsCubit.state.sessions));
                    }
                    final cs = clientBloc.state;
                    if (cs is ClientLoaded) {
                      unawaited(cubit.schedulePaymentReminders(cs.entities));
                    }

                    // Subscribe to changes.
                    cubit.bindToStreams(
                      sessionsStream: sessionsCubit.stream,
                      clientStream: clientBloc.stream,
                    );
                    return cubit;
                  },
                ),
              ],
              child: const DashboardScreen(),
            );
          },
        );
      },
    );
  }
}
