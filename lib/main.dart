import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/di/service_locator.dart';
import 'core/firebase/firestore_db.dart';
import 'core/platform/web_online_status.dart';
import 'core/services/notification_service.dart';
import 'design_system/theme/app_theme.dart';
import 'design_system/theme/app_chrome_theme.dart';
import 'firebase_options_dev.dart';
import 'features/landing/ui/landing_screen.dart';
import 'features/theme_customization/bloc/app_theme_cubit.dart';
import 'features/theme_customization/bloc/app_theme_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    final online = isBrowserOnline;
    debugPrint('Startup: platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}, browserOnline=$online');
    try {
      // Firestore connectivity probe (no PII, no writes).
      await firestoreDb.collection('__health').doc('ping').get();
      debugPrint('Startup: Firestore health probe OK');
    } on FirebaseException catch (e) {
      debugPrint('Startup: Firestore health probe failed: code=${e.code} message=${e.message}');
    } catch (e) {
      debugPrint('Startup: Firestore health probe failed: $e');
    }
  }

  await setupServiceLocator();
  await NotificationService.instance.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AppThemeCubit()),
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
            ),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: state.darkBackground,
              chromeTheme: chromeDark,
              font: state.font,
            ),
            themeMode: state.themeMode,
            home: const LandingScreen(),
          );
        },
      ),
    );
  }
}
