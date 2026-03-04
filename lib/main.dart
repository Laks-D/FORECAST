import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/service_locator.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_cubit.dart';
import 'design_system/theme/app_theme.dart';
import 'design_system/theme/app_chrome_theme.dart';
import 'features/auth/login/ui/login_screen.dart';
import 'features/calendar/bloc/sessions_cubit.dart';
import 'features/client/presentation/bloc/client_bloc.dart';
import 'features/client/presentation/bloc/client_event.dart';
import 'features/navigation/bloc/nav_modules_cubit.dart';
import 'features/theme_customization/bloc/app_theme_cubit.dart';
import 'features/theme_customization/bloc/app_theme_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        BlocProvider(create: (_) => NavModulesCubit()),
        BlocProvider(create: (_) => sl<SessionsCubit>()),
        BlocProvider(create: (_) => sl<ClientBloc>()..add(LoadClients())),
        BlocProvider(create: (_) => NotificationCubit()..load()),
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
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}
