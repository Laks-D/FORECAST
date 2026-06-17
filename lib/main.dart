import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/di/service_locator.dart';
import 'core/app/app_mode.dart';
import 'core/app/app_mode_cubit.dart';
import 'core/firebase/firestore_db.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_orchestrator.dart';
import 'core/services/deep_link_service.dart';
import 'core/profile/user_profile_cubit.dart';
import 'design_system/theme/app_theme.dart';
import 'design_system/theme/app_chrome_theme.dart';
import 'firebase_options.dart';
import 'features/landing/ui/landing_screen.dart';
import 'features/calendar/bloc/sessions_cubit.dart';
import 'features/theme_customization/bloc/app_theme_cubit.dart';
import 'features/theme_customization/bloc/app_theme_state.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await runConfiguredApp();
  } catch (e, st) {
    debugPrint('Fatal error during startup: $e');
    debugPrintStack(stackTrace: st);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Startup Error:\n$e\n\n$st',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> runConfiguredApp({AppMode? forcedMode}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (forcedMode != null) AppModeConfig.mode = forcedMode;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If the native Android/iOS SDK already auto-initialized the default app 
    // (using google-services.json / GoogleService-Info.plist), it will throw duplicate-app.
    // We can safely ignore this and proceed.
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase [DEFAULT] app already initialized natively. Proceeding.');
    } else {
      rethrow;
    }
  }
  debugPrint('🔥 Firebase started successfully!');

  if (kIsWeb) {
    firestoreDb.settings = const Settings(
      // Do not persist any data locally on web.
      persistenceEnabled: false,
      ignoreUndefinedProperties: true,
      webExperimentalAutoDetectLongPolling: true,
      webExperimentalForceLongPolling: true,
    );
  }

  if (kDebugMode) {
    debugPrint('Startup: platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}');
  }

  await setupServiceLocator();
  NotificationService.instance.init();
  DeepLinkService.instance.init();
  runApp(App(forcedMode: forcedMode));

  // Attach the local notification orchestrator AFTER runApp.
  // This uses 100% local device alarms for ALL users (Tutors and Students),
  // removing any need for Firebase Cloud Functions or the Blaze plan.
  Future.delayed(const Duration(milliseconds: 500), () {
    NotificationOrchestrator.instance.attach(
      sessionsCubit: sl(),
      clientBloc: sl(),
    );
  });
}

class App extends StatelessWidget {
  const App({super.key, this.forcedMode});

  final AppMode? forcedMode;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppThemeCubit()),
        BlocProvider(create: (_) => AppModeCubit(forcedMode: forcedMode)),
        BlocProvider(create: (_) => UserProfileCubit()),
        BlocProvider(create: (_) => sl<SessionsCubit>()),
      ],
      child: BlocBuilder<AppThemeCubit, AppThemeState>(
        builder: (context, state) {
          final chromeLight = AppChromeTheme(
            frameColor: state.frameColor,
            accentBlue: state.accentBlue,
            surfaceColor: state.lightSurface,
            textColor: state.lightText,
            mutedColor: state.lightMuted,
          );

          final chromeDark = AppChromeTheme(
            frameColor: state.frameColor,
            accentBlue: state.accentBlue,
            surfaceColor: state.darkSurface,
            textColor: state.darkText,
            mutedColor: state.darkMuted,
          );

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
              brightness: Brightness.light,
              scaffoldBackgroundColor: state.lightBackground,
              chromeTheme: chromeLight,
              font: state.font,
              neumorphism: state.activeThemeId == 'neumorphism',
            ),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: state.darkBackground,
              chromeTheme: chromeDark,
              font: state.font,
              neumorphism: state.activeThemeId == 'neumorphism',
            ),
            themeMode: state.themeMode,
            navigatorKey: DeepLinkService.instance.navigatorKey,
            home: const LandingScreen(),
          );
        },
      ),
    );
  }
}
