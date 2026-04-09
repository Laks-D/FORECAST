import 'package:flutter/widgets.dart';

enum AppMode {
  admin,
  client,
}

/// Process-wide app-mode configuration.
///
/// We keep this as a simple static so non-UI layers (BLoCs/repositories)
/// can enforce read-only behavior in the client app.
class AppModeConfig {
  static AppMode mode = AppMode.admin;

  static bool get isClient => mode == AppMode.client;
  static bool get isAdmin => mode == AppMode.admin;
}

class AppModeScope extends InheritedWidget {
  const AppModeScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final AppMode mode;

  static AppMode of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppModeScope>();
    return scope?.mode ?? AppModeConfig.mode;
  }

  static bool isClient(BuildContext context) => of(context) == AppMode.client;

  @override
  bool updateShouldNotify(AppModeScope oldWidget) => oldWidget.mode != mode;
}
