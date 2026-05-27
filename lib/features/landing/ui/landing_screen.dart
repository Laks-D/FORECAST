import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app/app_mode.dart';
import '../../../core/app/app_mode_cubit.dart';
import '../../../core/app/app_mode_storage.dart';
import '../../../core/dev/dev_bootstrap.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/firebase/firestore_db.dart';
import '../../../core/services/notification_cubit.dart';
import '../../auth/login/ui/login_screen.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../../dashboard/ui/dashboard_screen.dart';
import '../../join_request/bloc/join_request_listener_cubit.dart';
import '../../navigation/bloc/nav_modules_cubit.dart';

class _Roles {
  const _Roles({required this.isStudent, required this.isTutor});
  final bool isStudent;
  final bool isTutor;
  bool get isDualRole => isStudent && isTutor;
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final Future<void> _bootstrap;

  String? _lastCheckedUid;
  Future<_Roles>? _rolesFuture;

  @override
  void initState() {
    super.initState();
    _bootstrap = runDevBootstrap();
  }

  Future<_Roles> _getRolesFuture(String uid) {
    if (_lastCheckedUid == uid && _rolesFuture != null) return _rolesFuture!;
    _lastCheckedUid = uid;
    _rolesFuture = _checkRoles(uid);
    return _rolesFuture!;
  }

  Future<_Roles> _checkRoles(String uid) async {
    // 1. Explicit roles array (written at signup / QR enrollment).
    try {
      final snap = await firestoreDb.collection('users').doc(uid).get();
      final raw = snap.data()?['roles'];
      if (raw is List && raw.isNotEmpty) {
        final roles = raw.cast<String>();
        return _Roles(
          isStudent: roles.contains('student'),
          isTutor: roles.contains('tutor'),
        );
      }
    } catch (_) {}

    // 2. Legacy fallback: infer from sub-collections & backfill.
    bool isStudent = false;
    bool isTutor = false;
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('enrollment')
          .limit(1)
          .get();
      isStudent = s.docs.isNotEmpty;
    } catch (_) {}
    try {
      final s = await firestoreDb
          .collection('users')
          .doc(uid)
          .collection('clients')
          .limit(1)
          .get();
      isTutor = s.docs.isNotEmpty;
    } catch (_) {}
    if (!isTutor) {
      try {
        final s = await firestoreDb
            .collection('organizations')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .get();
        isTutor = s.docs.isNotEmpty;
      } catch (_) {}
    }
    if (isStudent || isTutor) {
      firestoreDb
          .collection('users')
          .doc(uid)
          .set(
            {'roles': [if (isTutor) 'tutor', if (isStudent) 'student']},
            SetOptions(merge: true),
          )
          .ignore();
    }
    return _Roles(isStudent: isStudent, isTutor: isTutor);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, _) {
        return BlocBuilder<AppModeCubit, AppModeState>(
          builder: (context, modeState) {
            // ── Wait for AppModeCubit to load the saved mode from storage.
            // Reading mode before it loads gives null → defaults to admin →
            // students get stuck on the wrong screen on every app restart.
            if (!modeState.loaded) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (Firebase.apps.isEmpty) {
              return const LoginScreen();
            }

            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnap) {
                if (authSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final user = authSnap.data;
                if (user == null) return const LoginScreen();

                return FutureBuilder<_Roles>(
                  future: _getRolesFuture(user.uid),
                  builder: (context, rolesSnap) {
                    if (rolesSnap.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final roles = rolesSnap.data ??
                        const _Roles(isStudent: false, isTutor: false);

                    // ── Dual-role: the tab they logged in through decides mode.
                    if (roles.isDualRole) {
                      AppModeConfig.isDualRole = true;
                      // Use the mode currently in AppModeCubit (set by tab tap
                      // at login, or restored from storage on app restart).
                      final mode = modeState.mode ?? AppMode.admin;
                      AppModeConfig.mode = mode;
                      AppModeStorage.save(mode);
                      return _buildApp(
                          user: user, appMode: mode, isDualRole: true);
                    }

                    AppModeConfig.isDualRole = false;

                    // ── Single-role: always auto-route to the correct dashboard
                    // regardless of which tab was selected.  This prevents
                    // students being trapped on the wrong screen when the saved
                    // mode doesn't match their role (e.g. first install, cleared
                    // storage, or after role changes).
                    if (roles.isTutor) {
                      AppModeConfig.mode = AppMode.admin;
                      AppModeStorage.save(AppMode.admin);
                      return _buildApp(
                          user: user,
                          appMode: AppMode.admin,
                          isDualRole: false);
                    }

                    if (roles.isStudent) {
                      AppModeConfig.mode = AppMode.client;
                      AppModeStorage.save(AppMode.client);
                      return _buildApp(
                          user: user,
                          appMode: AppMode.client,
                          isDualRole: false);
                    }

                    // ── No role yet (brand-new user, signup still in progress).
                    // Use whatever tab was selected; signup will write the role.
                    final fallback = modeState.mode ?? AppMode.admin;
                    AppModeConfig.mode = fallback;
                    return _buildApp(
                        user: user, appMode: fallback, isDualRole: false);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildApp({
    required User user,
    required AppMode appMode,
    required bool isDualRole,
  }) {
    final isStudent = appMode == AppMode.client;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NotificationCubit()),
        BlocProvider(create: (_) => sl<ClientBloc>()..add(LoadClients())),
        BlocProvider(create: (_) => sl<NavModulesCubit>()),
        if (!isStudent)
          BlocProvider(
            create: (_) =>
                JoinRequestListenerCubit()..startForAdmin(user.uid),
          ),
      ],
      child: AppModeScope(
        mode: appMode,
        child: DashboardScreen(
          initialUserName: user.displayName,
          initialUserEmail: user.email,
          canSwitchMode: isDualRole,
        ),
      ),
    );
  }
}
