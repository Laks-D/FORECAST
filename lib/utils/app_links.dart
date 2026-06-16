/// Utility class for generating and parsing onboarding/invite links.
///
/// Links encode: tutorId + timestamp (ts).
/// No organisation concept exists in this app.
class OnboardingLink {
  static const String _baseUrl = 'https://genericapp-prod.web.app/join';

  /// Generate an invite link for the given [tutorId] with a fresh [ts] timestamp.
  static String generateLink(String tutorId, String ts) {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'tutorId': tutorId, 'ts': ts},
    );
    return uri.toString();
  }

  /// Parse the tutorId from an invite URL or raw QR payload.
  static String? parseTutorId(String url) => parse(url).$1;

  /// Parse the timestamp from an invite URL or raw QR payload.
  static String? parseTimestamp(String url) => parse(url).$2;

  /// Robustly extract `(tutorId, ts)` from any of:
  ///  - a full invite URL: `https://genericapp-prod.web.app/join?tutorId=X&ts=Y`
  ///  - a query string only: `tutorId=X&ts=Y`
  ///  - a bare tutorId (no `=`/`&`/`?`): treated as the tutorId, ts null
  ///
  /// Used by both the QR scanner and the manual code-entry fallback, so a tutor
  /// can share the link (copy/share) and the student can paste it anywhere.
  static (String?, String?) parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return (null, null);

    // 1) Try as-is (full URL with scheme + query).
    final direct = _fromUri(Uri.tryParse(raw));
    if (direct.$1 != null) return direct;

    // 2) Looks like a query fragment (`tutorId=..&ts=..`) — wrap it.
    if (raw.contains('=')) {
      final wrapped = _fromUri(Uri.tryParse('https://placeholder/?$raw'));
      if (wrapped.$1 != null) return wrapped;
    }

    // 3) Bare value — assume it is the tutorId itself (no whitespace/url chars).
    if (!raw.contains(RegExp(r'[\s/?&]'))) return (raw, null);

    return (null, null);
  }

  static (String?, String?) _fromUri(Uri? uri) {
    if (uri == null) return (null, null);
    final tutorId = uri.queryParameters['tutorId'];
    final ts = uri.queryParameters['ts'];
    return ((tutorId != null && tutorId.isNotEmpty) ? tutorId : null, ts);
  }
}
