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
  static String? parseTutorId(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['tutorId'];
    } catch (_) {
      return null;
    }
  }

  /// Parse the timestamp from an invite URL or raw QR payload.
  static String? parseTimestamp(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['ts'];
    } catch (_) {
      return null;
    }
  }
}
