/// Utility class for generating and parsing onboarding links
class OnboardingLink {
  static const String _baseUrl = 'https://my-admin-app.web.app/join';

  /// @deprecated Organizations are removed. Use [generateLinkWithTutor] instead.
  /// Kept temporarily for any lingering call-sites that haven't been updated.
  static String generateLink(String orgId) {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'orgId': orgId},
    );
    return uri.toString();
  }

  /// Generate an onboarding link that includes a tutor id and timestamp.
  static String generateLinkWithTutor(String? orgId, String tutorId, String ts) {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        if (orgId != null) 'orgId': orgId,
        'tutorId': tutorId,
        'ts': ts,
      },
    );
    return uri.toString();
  }

  /// Parse the orgId from an onboarding URL
  ///
  /// Returns null if the URL is invalid or does not contain an orgId parameter.
  ///
  /// Example:
  /// ```dart
  /// final orgId = OnboardingLink.parseOrgId(
  ///   'https://my-admin-app.web.app/join?orgId=org-123'
  /// );
  /// // Returns: org-123
  /// ```
  static String? parseOrgId(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['orgId'];
    } catch (e) {
      return null;
    }
  }

  /// Parse tutor id from an onboarding URL or QR payload.
  static String? parseTutorId(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['tutorId'];
    } catch (e) {
      return null;
    }
  }

  /// Parse timestamp from an onboarding URL or QR payload.
  static String? parseTimestamp(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['ts'];
    } catch (e) {
      return null;
    }
  }
}
