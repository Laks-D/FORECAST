import 'core/app/app_mode.dart';
import 'main.dart' as main_app;

/// Client app entrypoint.
///
/// Run with:
/// - `flutter run -t lib/main_client.dart`
/// - `flutter build apk --release -t lib/main_client.dart`
Future<void> main() async {
  await main_app.runConfiguredApp(forcedMode: AppMode.client);
}

