
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/dev/dev_bootstrap.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/notification_cubit.dart';
import '../../auth/login/ui/login_screen.dart';
import '../../client/presentation/bloc/client_bloc.dart';
import '../../client/presentation/bloc/client_event.dart';
import '../../dashboard/ui/dashboard_screen.dart';

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
	Widget build(BuildContext context) {
		return FutureBuilder<void>(
			future: _bootstrap,
			builder: (context, snap) {
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
						if (user == null) {
							return const LoginScreen();
						}

						return MultiBlocProvider(
							providers: [
								BlocProvider(create: (_) => NotificationCubit()),
								BlocProvider(
									create: (_) => sl<ClientBloc>()..add(LoadClients()),
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

