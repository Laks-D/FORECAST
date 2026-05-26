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
}

/// App root that decides whether to show auth screens or the signed-in app.
class LandingScreen extends StatefulWidget {
	const LandingScreen({super.key});

	@override
	State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
	late final Future<void> _bootstrap;

	// Cache the role-check future per UID so FutureBuilder does not re-fire
	// every time BlocBuilder<AppModeCubit> rebuilds.
	String? _lastCheckedUid;
	Future<_Roles>? _rolesFuture;

	/// The user's preferred app mode — loaded from Firestore on init and
	/// updated whenever they pick a mode in the chooser or switch in Settings.
	AppMode? _savedMode;

	@override
	void initState() {
		super.initState();
		_bootstrap = _init();
	}

	/// Runs dev bootstrap AND loads the saved mode preference in parallel so
	/// the FutureBuilder waits for both before rendering any signed-in content.
	Future<void> _init() async {
		await Future.wait([
			runDevBootstrap(),
			_loadSavedMode(),
		]);
	}

	Future<void> _loadSavedMode() async {
		try {
			_savedMode = await AppModeStorage.load();
		} catch (_) {
			// Non-fatal — we'll fall back to the mode chooser.
		}
		_modeLoaded = true;
	}

	Future<_Roles> _getRolesFuture(String uid) {
		if (_lastCheckedUid == uid && _rolesFuture != null) {
			return _rolesFuture!;
		}
		_lastCheckedUid = uid;
		_rolesFuture = _checkRoles(uid);
		return _rolesFuture!;
	}

	/// Returns whether the signed-in user is a student and/or a tutor.
	///
	/// Reads the explicit `roles` array from `users/{uid}` first (written at
	/// signup and on QR enrollment).  Falls back to collection-count inference
	/// for legacy accounts that predate the roles field.
	Future<_Roles> _checkRoles(String uid) async {
		// ── 1. Try the explicit roles array ──────────────────────────────────
		try {
			final userSnap = await firestoreDb.collection('users').doc(uid).get();
			final rawRoles = userSnap.data()?['roles'];
			if (rawRoles is List && rawRoles.isNotEmpty) {
				final roles = rawRoles.cast<String>();
				return _Roles(
					isStudent: roles.contains('student'),
					isTutor: roles.contains('tutor'),
				);
			}
		} catch (_) {}

		// ── 2. Legacy fallback: infer from sub-collections ───────────────────
		bool isStudent = false;
		bool isTutor = false;

		try {
			final snap = await firestoreDb
					.collection('users')
					.doc(uid)
					.collection('enrollment')
					.limit(1)
					.get();
			isStudent = snap.docs.isNotEmpty;
		} catch (_) {}

		try {
			final snap = await firestoreDb
					.collection('users')
					.doc(uid)
					.collection('clients')
					.limit(1)
					.get();
			isTutor = snap.docs.isNotEmpty;
		} catch (_) {}

		if (!isTutor) {
			try {
				final snap = await firestoreDb
						.collection('organizations')
						.where('ownerId', isEqualTo: uid)
						.limit(1)
						.get();
				isTutor = snap.docs.isNotEmpty;
			} catch (_) {}
		}

		// Backfill the roles field so next login is faster.
		if (isStudent || isTutor) {
			final roles = <String>[
				if (isTutor) 'tutor',
				if (isStudent) 'student',
			];
			firestoreDb
					.collection('users')
					.doc(uid)
					.set({'roles': roles}, SetOptions(merge: true))
					.ignore();
		}

		return _Roles(isStudent: isStudent, isTutor: isTutor);
	}

	@override
	Widget build(BuildContext context) {
		return FutureBuilder<void>(
			future: _bootstrap,
			builder: (context, snap) {
				return BlocBuilder<AppModeCubit, AppModeState>(
					buildWhen: (p, n) => p.loaded != n.loaded,
					builder: (context, modeState) {
						if (Firebase.apps.isEmpty) {
							if (!modeState.loaded) {
								return const Scaffold(
									body: Center(child: CircularProgressIndicator()),
								);
							}
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
								if (user == null) {
									return const LoginScreen();
								}

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

										if (roles.isDualRole) {
											AppModeConfig.isDualRole = true;

											// If a mode preference is already saved, go directly to
											// the dashboard without showing the chooser again.
											final preferred = _savedMode;
											if (preferred != null) {
												AppModeConfig.mode = preferred;
												return _buildApp(
													user: user,
													appMode: preferred,
													isDualRole: true,
												);
											}

											// No saved preference → let the user pick.
											return _ModeChooser(
												user: user,
												onModeSelected: (mode) {
													AppModeConfig.mode = mode;
													AppModeStorage.save(mode);
													setState(() => _savedMode = mode);
												},
											);
										}

										// Single-role: auto-assign.
										AppModeConfig.isDualRole = false;
										final appMode =
												roles.isStudent ? AppMode.client : AppMode.admin;
										AppModeConfig.mode = appMode;
										AppModeStorage.save(appMode);

										return _buildApp(
											user: user,
											appMode: appMode,
											isDualRole: false,
										);
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
				BlocProvider(
					create: (_) => sl<ClientBloc>()..add(LoadClients()),
				),
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

// ── MODE CHOOSER ─────────────────────────────────────────────────────────────

/// Shown only to dual-role users (enrolled as student AND have tutor access).
class _ModeChooser extends StatelessWidget {
	const _ModeChooser({required this.user, required this.onModeSelected});

	final User user;
	final void Function(AppMode) onModeSelected;

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
							CircleAvatar(
								radius: 40,
								backgroundColor: scheme.primaryContainer,
								child: Text(
									(user.displayName?.isNotEmpty == true
													? user.displayName![0]
													: user.email?[0] ?? 'U')
											.toUpperCase(),
									style: TextStyle(
										fontSize: 32,
										fontWeight: FontWeight.w800,
										color: scheme.onPrimaryContainer,
									),
								),
							),
							const SizedBox(height: 20),
							Text(
								'Welcome back${user.displayName?.isNotEmpty == true ? ', ${user.displayName!.split(' ').first}' : ''}!',
								style: Theme.of(context).textTheme.headlineSmall?.copyWith(
											fontWeight: FontWeight.w800,
										),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 8),
							Text(
								'How would you like to continue?',
								style: Theme.of(context).textTheme.bodyLarge?.copyWith(
											color: scheme.onSurface.withOpacity(0.6),
										),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 40),
							_RoleCard(
								icon: Icons.school_rounded,
								title: 'Continue as Tutor',
								subtitle: 'Manage clients, sessions & payments',
								color: const Color(0xFF6C63FF),
								onTap: () => onModeSelected(AppMode.admin),
							),
							const SizedBox(height: 16),
							_RoleCard(
								icon: Icons.person_rounded,
								title: 'Continue as Student',
								subtitle: 'View your sessions & progress',
								color: const Color(0xFF22C55E),
								onTap: () => onModeSelected(AppMode.client),
							),
						],
					),
				),
			),
		);
	}
}

class _RoleCard extends StatelessWidget {
	const _RoleCard({
		required this.icon,
		required this.title,
		required this.subtitle,
		required this.color,
		required this.onTap,
	});

	final IconData icon;
	final String title;
	final String subtitle;
	final Color color;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		final scheme = Theme.of(context).colorScheme;

		return Material(
			color: color.withOpacity(0.08),
			borderRadius: BorderRadius.circular(20),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(20),
				child: Padding(
					padding: const EdgeInsets.all(20),
					child: Row(
						children: [
							Container(
								width: 52,
								height: 52,
								decoration: BoxDecoration(
									color: color.withOpacity(0.15),
									borderRadius: BorderRadius.circular(14),
								),
								child: Icon(icon, color: color, size: 28),
							),
							const SizedBox(width: 16),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											title,
											style:
													Theme.of(context).textTheme.titleMedium?.copyWith(
																fontWeight: FontWeight.w700,
															),
										),
										const SizedBox(height: 2),
										Text(
											subtitle,
											style: Theme.of(context).textTheme.bodySmall?.copyWith(
														color: scheme.onSurface.withOpacity(0.55),
													),
										),
									],
								),
							),
							Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
						],
					),
				),
			),
		);
	}
}
