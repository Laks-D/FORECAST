import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/client/presentation/ui/invite_landing_page.dart';

/// Listens for incoming Android App Links / iOS Universal Links and navigates
/// to [InviteLandingPage] when the app is opened via an invite URL.
class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<Uri>? _sub;

  void init() {
    _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handleUri(Uri uri) {
    if (uri.host != 'genericapp-prod.web.app') return;
    if (!uri.path.startsWith('/join')) return;

    final tutorId = uri.queryParameters['tutorId'];
    final ts = uri.queryParameters['ts'];

    _pushWhenReady(tutorId, ts);
  }

  Future<void> _pushWhenReady(String? tutorId, String? ts) async {
    while (navigatorKey.currentContext == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final ctx = navigatorKey.currentContext!;
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => InviteLandingPage(
          tutorId: tutorId,
          qrTimestampMs: ts,
        ),
      ),
    );
  }
}
