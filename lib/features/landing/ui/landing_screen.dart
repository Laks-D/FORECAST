

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/dev/dev_bootstrap.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/app/app_mode_cubit.dart';
import '../../../core/app/app_mode.dart';
import '../../../core/services/notification_cubit.dart';
import '../../auth/login/ui/login_screen.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../../client/presentation/pages/client_profile_page.dart';
import '../../client/domain/usecases/get_clients_usecase.dart';
import '../../client/domain/repositories/client_repository.dart';
import '../../dashboard/ui/dashboard_screen.dart';
import '../../join_request/bloc/join_request_listener_cubit.dart';
import '../../navigation/bloc/nav_modules_cubit.dart';

/// App root that decides whether to show auth screens or the signed-in app.
///
/// Several features assume certain global BLoCs exist above the dashboard
/// (clients, sessions, nav modules, notifications). This screen provides them.
class LandingScreen extends StatefulWidget {
	const LandingScreen({super.key});

	@override
	State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
	late final Future<void> _bootstrap;

	@override
	void initState() {
		super.initState();
		// Best-effort: enables dev-mode anonymous sign-in when SKIP_AUTH=true.
		_bootstrap = runDevBootstrap();
	}

	@override
	void dispose() {
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return FutureBuilder<void>(
			future: _bootstrap,
			builder: (context, snap) {
				return BlocBuilder<AppModeCubit, AppModeState>(
					buildWhen: (p, n) => p.loaded != n.loaded || p.mode != n.mode,
					builder: (context, modeState) {
						// Widget tests (and some non-app entrypoints) may build the widget
						// tree without calling Firebase.initializeApp(). In the real app,
						// main() initializes Firebase before runApp.
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
								// Avoid flashing the login screen during initial auth restore.
								if (authSnap.connectionState == ConnectionState.waiting) {
									return const Scaffold(
										body: Center(child: CircularProgressIndicator()),
									);
								}

																final user = authSnap.data;

																// If there's no authenticated user, show the login UI.
																if (user == null) {
																	return const LoginScreen();
																}

																// Determine whether this authenticated user maps to a client record.
																// We load local clients from storage and check for an email match.
																return FutureBuilder<void>(
																	future: sl<ClientRepository>().loadFromStorage(),
																	builder: (context, snapClients) {
																		if (snapClients.connectionState == ConnectionState.waiting) {
																			return const Scaffold(
																				body: Center(child: CircularProgressIndicator()),
																			);
																		}

																		final clients = sl<GetClientsUseCase>().execute();
																		final userEmail = (user.email ?? '').trim().toLowerCase();
																		final matched = clients.cast<dynamic?>().firstWhere(
																			(c) => c != null && ((c as dynamic).email as String?)?.trim().toLowerCase() == userEmail,
																			orElse: () => null,
																		);

																		if (matched != null) {
																			// Signed-in user is a client — switch to client mode and show profile.
																			try {
																				context.read<AppModeCubit>().setMode(AppMode.client);
																			} catch (_) {}

																			final clientEntity = matched as dynamic;
																			return MultiBlocProvider(
																				providers: [
																					BlocProvider(create: (_) => NotificationCubit()),
																					BlocProvider(
																						create: (_) => sl<ClientBloc>()..add(LoadClients()),
																					),
																					BlocProvider(create: (_) => sl<NavModulesCubit>()),
																				],
																				child: AppModeScope(
																					mode: AppMode.client,
																					child: ClientProfilePage(entity: clientEntity),
																				),
																			);
																		}

																		// Default: show tutor/dashboard view.
																		return MultiBlocProvider(
																			providers: [
																				BlocProvider(create: (_) => NotificationCubit()),
																				BlocProvider(
																					create: (_) => sl<ClientBloc>()..add(LoadClients()),
																				),
																				BlocProvider(create: (_) => sl<NavModulesCubit>()),
																											BlocProvider(
																												create: (_) => JoinRequestListenerCubit()..startForAdmin(user.uid),
																											),
																			],
																			child: AppModeScope(
																				mode: modeState.mode ?? AppMode.admin,
																				child: const DashboardScreen(),
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

