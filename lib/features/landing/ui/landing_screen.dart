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

/// App root that decides whether to show auth screens or the signed-in app.
class LandingScreen extends StatefulWidget {
	const LandingScreen({super.key});

	@override
	State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
	late final Future<void> _bootstrap;

	// Cache the enrollment future per UID so FutureBuilder does not re-fire
	// every time BlocBuilder<AppModeCubit> rebuilds, which would recreate
	// MultiBlocProvider and kill the ClientBloc holding the newly added client.
	String? _lastCheckedUid;
	Future<bool>? _enrollmentFuture;

	@override
	void initState() {
		super.initState();
		_bootstrap = runDevBootstrap();
	}

	Future<bool> _getEnrollmentFuture(String uid) {
		if (_lastCheckedUid == uid && _enrollmentFuture != null) {
			return _enrollmentFuture!;
		}
		_lastCheckedUid = uid;
		_enrollmentFuture = _checkEnrolled(uid);
		return _enrollmentFuture!;
	}

	Future<bool> _checkEnrolled(String uid) async {
		try {
			final snap = await firestoreDb
					.collection('users')
					.doc(uid)
					.collection('enrollment')
					.limit(1)
					.get();
			return snap.docs.isNotEmpty;
		} catch (_) {
			return false;
		}
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

								// Use cached future — prevents FutureBuilder from recreating
								// MultiBlocProvider on every AppModeCubit state change.
								return FutureBuilder<bool>(
									future: _getEnrollmentFuture(user.uid),
									builder: (context, enrollSnap) {
										if (enrollSnap.connectionState == ConnectionState.waiting) {
											return const Scaffold(
												body: Center(child: CircularProgressIndicator()),
											);
										}

										final isStudent = enrollSnap.data == true;
										final appMode = isStudent ? AppMode.client : AppMode.admin;

										// Set the static directly — avoids AppModeCubit.emit() which
										// would trigger BlocBuilder to rebuild and recreate ClientBloc.
										AppModeConfig.mode = appMode;
										AppModeStorage.save(appMode); // fire-and-forget persistence

										return MultiBlocProvider(
											providers: [
												BlocProvider(create: (_) => NotificationCubit()),
												BlocProvider(
													create: (_) => sl<ClientBloc>()..add(LoadClients()),
												),
												BlocProvider(create: (_) => sl<NavModulesCubit>()),
												if (!isStudent)
													BlocProvider(
														create: (_) => JoinRequestListenerCubit()
															..startForAdmin(user.uid),
													),
											],
											child: AppModeScope(
												mode: appMode,
												child: DashboardScreen(
													initialUserName: user.displayName,
													initialUserEmail: user.email,
												),
											),
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
}
