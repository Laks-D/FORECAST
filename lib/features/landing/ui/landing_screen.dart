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

/// Role detection result returned by [_checkRoles].
class _Roles {
  const _Roles({required this.isStudent, required this.isTutor});
  final bool isStudent;
  final bool isTutor;
  bool get isDualRole => isStudent && isTutor;
  bool get hasNoRole => !isStudent && !isTutor;
}

/// App root that decides whether to show auth screens or the signed-in app.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final Future<void> _bootstrap;

  // Cache the role-check future per UID so it doesn't re-fire on every rebuild.
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
      final s = await firestoreDb.collection('users').doc(uid).collection('enrollment').limit(1).get();
      isStudent = s.docs.isNotEmpty;
    } catch (_) {}
    try {
      final s = await firestoreDb.collection('users').doc(uid).collection('clients').limit(1).get();
      isTutor = s.docs.isNotEmpty;
    } catch (_) {}
    if (!isTutor) {
      try {
        final s = await firestoreDb.collection('organizations').where('ownerId', isEqualTo: uid).limit(1).get();
        isTutor = s.docs.isNotEmpty;
      } catch (_) {}
    }
    if (isStudent || isTutor) {
      firestoreDb.collection('users').doc(uid).set(
        {'roles': [if (isTutor) 'tutor', if (isStudent) 'student']},
        SetOptions(merge: true),
      ).ignore();
    }
    return _Roles(isStudent: isStudent, isTutor: isTutor);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, _) {
        return BlocBuilder<AppModeCubit, AppModeState>(
          buildWhen: (p, n) => p.loaded != n.loaded,
          builder: (context, modeState) {
            if (Firebase.apps.isEmpty) {
              if (!modeState.loaded) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return const LoginScreen();
            }

            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnap) {
                if (authSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final user = authSnap.data;
                if (user == null) return const LoginScreen();

                return FutureBuilder<_Roles>(
                  future: _getRolesFuture(user.uid),
                  builder: (context, rolesSnap) {
                    if (rolesSnap.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }

                    final roles = rolesSnap.data ?? const _Roles(isStudent: false, isTutor: false);

                    // The tab the user selected at login is the source of truth.
                    // AppModeCubit.setMode() is called whenever a chip is tapped,
                    // so it always reflects the current selection (or the last
                    // saved preference on app restart).
                    final selectedMode = context.read<AppModeCubit>().state.mode ?? AppMode.admin;

                    // ── Dual-role: trust their tab selection ──────────────────
                    if (roles.isDualRole) {
                      AppModeConfig.isDualRole = true;
                      AppModeConfig.mode = selectedMode;
                      AppModeStorage.save(selectedMode);
                      return _buildApp(user: user, appMode: selectedMode, isDualRole: true);
                    }

                    AppModeConfig.isDualRole = false;

                    // ── Single-role: validate tab matches actual role ─────────
                    if (roles.isTutor) {
                      if (selectedMode == AppMode.client) {
                        // Tutor trying to use Student tab → block.
                        return _AccessDeniedPage(
                          message: 'You are registered as a tutor.\nPlease use the Tutor tab to log in.',
                        );
                      }
                      AppModeConfig.mode = AppMode.admin;
                      AppModeStorage.save(AppMode.admin);
                      return _buildApp(user: user, appMode: AppMode.admin, isDualRole: false);
                    }

                    if (roles.isStudent) {
                      if (selectedMode == AppMode.admin) {
                        // Student trying to use Tutor tab → block.
                        return _AccessDeniedPage(
                          message: 'You are registered as a student.\nPlease use the Student tab to log in.',
                        );
                      }
                      AppModeConfig.mode = AppMode.client;
                      AppModeStorage.save(AppMode.client);
                      return _buildApp(user: user, appMode: AppMode.client, isDualRole: false);
                    }

                    // ── No role yet (brand-new user before signup completes) ──
                    // Route to whichever dashboard matches their tab selection;
                    // the signup form will write the role.
                    AppModeConfig.mode = selectedMode;
                    return _buildApp(user: user, appMode: selectedMode, isDualRole: false);
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
            create: (_) => JoinRequestListenerCubit()..startForAdmin(user.uid),
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

// ── Access Denied page ────────────────────────────────────────────────────────

/// Shown inside LandingScreen (not the login screen) when the user's roles
/// don't match the tab they selected.  The error stays visible until they
/// explicitly tap "Back to Login", which then signs them out cleanly.
class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: scheme.error, size: 34),
              ),
              const SizedBox(height: 24),
              Text(
                'Wrong login tab',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withOpacity(0.65),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Login'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
