import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/app/app_mode.dart';
import '../../../core/app/app_mode_cubit.dart';
import '../../../core/app/student_enrollment_resolver.dart';
import '../../../core/auth/login_controller.dart';
import '../../../core/auth/signup_controller.dart';
import '../../../core/dev/dev_bootstrap.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/notification_cubit.dart';
import '../../auth/repository/auth_repository.dart';
import '../../auth/ui/auth_gate.dart';
import '../../calendar/bloc/sessions_cubit.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../../dashboard/ui/dashboard_screen.dart';
import '../../join_request/bloc/join_request_listener_cubit.dart';
import '../../navigation/bloc/nav_modules_cubit.dart';
import '../../notifications/data/fcm_token_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final Future<void> _bootstrap;

  // ── Role-cache ────────────────────────────────────────────────────────────
  // Keyed by UID so a fresh sign-in always re-fetches from Firestore.
  String? _cachedRoleUid;
  Future<List<String>>? _rolesFuture;

  // Tracks the previous auth user so we detect sign-out → sign-in for the
  // SAME uid (e.g. signup → sign out → login).
  String? _previousUid;

  // Key incremented on each sign-out so AuthGate always gets a fresh
  // initState call and can read pending signup state.
  int _authGateGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap = runDevBootstrap();
  }

  void _invalidateRolesCache() {
    _cachedRoleUid = null;
    _rolesFuture = null;
  }

  Future<List<String>> _getRolesFuture(String uid) {
    if (_cachedRoleUid == uid && _rolesFuture != null) return _rolesFuture!;
    _cachedRoleUid = uid;
    _rolesFuture = AuthRepository.instance.fetchRoles(uid);
    return _rolesFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, _) {
        if (Firebase.apps.isEmpty) {
          return AuthGate(key: ValueKey(_authGateGeneration));
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return const _Spinner();
            }

            final user = authSnap.data;

            // ── Not signed in ──────────────────────────────────────────────
            if (user == null) {
              _invalidateRolesCache();
              // Fix C: clear enrollment cache so the next sign-in always
              // re-fetches the correct tutor UID from Firestore.
              StudentEnrollmentResolver.invalidateCache();
              // Forget the FCM-registered uid so the next user re-registers.
              FcmTokenService.instance.reset();
              // Bump generation so AuthGate is always a fresh instance and
              // its initState reliably reads any pending signup state.
              if (_previousUid != null) {
                _authGateGeneration++;
              }
              _previousUid = null;
              return AuthGate(key: ValueKey(_authGateGeneration));
            }

            // ── Signup in progress: block dashboard routing ─────────────────
            if (SignupController.instance.isSignupInProgress) {
              return const _Spinner();
            }

            // ── Fresh sign-in: always re-fetch roles ───────────────────────
            if (_previousUid == null || _previousUid != user.uid) {
              _invalidateRolesCache();
            }
            _previousUid = user.uid;

            // Register this device's FCM token (guarded; deduped per uid).
            FcmTokenService.instance.registerCurrentDevice();

            // ── Role check → dashboard ─────────────────────────────────────
            return BlocBuilder<AppModeCubit, AppModeState>(
              builder: (context, modeState) {
                return FutureBuilder<List<String>>(
                  future: _getRolesFuture(user.uid),
                  builder: (context, rolesSnap) {
                    if (rolesSnap.connectionState == ConnectionState.waiting) {
                      return const _Spinner();
                    }

                    final roles = rolesSnap.data ?? [];

                    final isTutor = roles.contains('tutor');
                    final isClient =
                        roles.contains('client') || roles.contains('student');

                    // Dual-role: route to the dashboard that matches the login tab
                    // used this session. If no login happened yet this session
                    // (e.g., app restarted while already signed in), fall back to
                    // tutor dashboard.
                    if (isTutor && isClient) {
                      final loginRole = LoginController.instance.lastLoginRole;
                      AppMode mode = modeState.mode ?? AppMode.admin;
                      if (loginRole != null) {
                        final expectedMode = loginRole == 'client' ? AppMode.client : AppMode.admin;
                        LoginController.instance.lastLoginRole = null;
                        if (mode != expectedMode) {
                          mode = expectedMode;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              context.read<AppModeCubit>().setMode(expectedMode);
                            }
                          });
                        }
                      }
                      
                      AppModeConfig.isDualRole = true;
                      AppModeConfig.mode = mode;
                      return _buildDashboard(
                          user: user, appMode: mode, isDualRole: true);
                    }

                    AppModeConfig.isDualRole = false;

                    if (isTutor) {
                      AppModeConfig.mode = AppMode.admin;
                      return _buildDashboard(
                          user: user, appMode: AppMode.admin, isDualRole: false);
                    }

                    if (isClient) {
                      AppModeConfig.mode = AppMode.client;
                      return _buildDashboard(
                          user: user, appMode: AppMode.client, isDualRole: false);
                    }

                    // No role found — role write may have failed during signup.
                    // Auto-sign-out after a short delay.
                    return _RolelessScreen(onSignOut: _invalidateRolesCache);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard({
    required User user,
    required AppMode appMode,
    required bool isDualRole,
  }) {
    final isClient = appMode == AppMode.client;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NotificationCubit()),
        BlocProvider(create: (_) => sl<ClientBloc>()..add(LoadClients())),
        BlocProvider(create: (_) => sl<NavModulesCubit>()),
        if (!isClient)
          BlocProvider(
            create: (_) =>
                JoinRequestListenerCubit()..startForAdmin(user.uid),
          ),
      ],
      child: AppModeScope(
        mode: appMode,
        child: Builder(
          builder: (ctx) {
            // Force re-init of singletons that rely on AppModeConfig
            ctx.read<SessionsCubit>().reinit();
            // Force reload of Client list for the specific mode/target
            ctx.read<ClientBloc>().add(LoadClients());
            return DashboardScreen(
              initialUserName: user.displayName,
              initialUserEmail: user.email,
              canSwitchMode: isDualRole,
            );
          },
        ),
      ),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

/// Shown when an authenticated user has no Firestore roles.
/// Auto-signs out after 3 seconds.
class _RolelessScreen extends StatefulWidget {
  const _RolelessScreen({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<_RolelessScreen> createState() => _RolelessScreenState();
}

class _RolelessScreenState extends State<_RolelessScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      widget.onSignOut();
      await FirebaseAuth.instance.signOut();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Setting up your account…'),
            ],
          ),
        ),
      );
}
