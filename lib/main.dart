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
import 'core/services/deep_link_service.dart';
import 'core/profile/user_profile_cubit.dart';
import 'design_system/theme/app_theme.dart';
import 'design_system/theme/app_chrome_theme.dart';
// Flavour-aware Firebase options.
// Run dev:  flutter run
// Run prod: flutter run --dart-define=FLAVOR=prod
import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
import 'features/landing/ui/landing_screen.dart';
import 'features/calendar/bloc/sessions_cubit.dart';
import 'features/theme_customization/bloc/app_theme_cubit.dart';
import 'features/theme_customization/bloc/app_theme_state.dart';

const _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runConfiguredApp();
}

Future<void> runConfiguredApp({AppMode? forcedMode}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (forcedMode != null) AppModeConfig.mode = forcedMode;
  await Firebase.initializeApp(
    options: _flavor == 'prod'
        ? prod_options.DefaultFirebaseOptions.currentPlatform
        : dev_options.DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('🔥 Firebase started — flavor: $_flavor');

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
  await NotificationService.instance.init();
  DeepLinkService.instance.init();
  runApp(App(forcedMode: forcedMode));
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
