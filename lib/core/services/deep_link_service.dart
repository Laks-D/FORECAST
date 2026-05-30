import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/client/presentation/ui/invite_landing_page.dart';

/// Listens for incoming Android App Links / iOS Universal Links and navigates
/// to [InviteLandingPage] when the app is opened via an invite URL.
///
/// Usage — call [DeepLinkService.init] once from [main] BEFORE [runApp], and
/// [DeepLinkService.attach] once the root [NavigatorKey] is available.
class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<Uri>? _sub;

  /// Start listening for incoming links.  Call from [main] or [LandingScreen].
  void init() {
    // Handle link when app is already running (foreground / background).
    _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});

    // Handle link that LAUNCHED the app (cold start).
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handleUri(Uri uri) {
    // Only handle our invite path.
    if (uri.host != 'genericapp-prod.web.app') return;
    if (!uri.path.startsWith('/join')) return;

    final tutorId = uri.queryParameters['tutorId'];
    final orgId = uri.queryParameters['orgId'];
    final ts = uri.queryParameters['ts'];

    _pushWhenReady(tutorId, orgId, ts);
  }

  Future<void> _pushWhenReady(String? tutorId, String? orgId, String? ts) async {
    // Wait until the navigator key is attached to the widget tree.
    while (navigatorKey.currentContext == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final ctx = navigatorKey.currentContext!;
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => InviteLandingPage(
          tutorId: tutorId,
          orgId: orgId,
          qrTimestampMs: ts,
        ),
      ),
    );
  }
}
