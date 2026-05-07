/// Exception thrown when link parsing fails
class LinkParsingException implements Exception {
  final String message;

  LinkParsingException(this.message);

  @override
  String toString() => 'LinkParsingException: $message';
}

/// Utility class for parsing incoming links and extracting parameters
class LinkHandler {
  /// Extracts the 'orgId' query parameter from a URL string.
  ///
  /// Throws [LinkParsingException] if:
  /// - The URL is malformed and cannot be parsed
  /// - The 'orgId' query parameter is missing or empty
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final orgId = LinkHandler.getOrgIdFromLink(
  ///     'https://my-admin-app.web.app/join?orgId=org-123'
  ///   );
  ///   print(orgId); // Output: org-123
  /// } on LinkParsingException catch (e) {
  ///   print('Error: ${e.message}');
  /// }
  /// ```
  static String getOrgIdFromLink(String url) {
    if (url.isEmpty) {
      throw LinkParsingException('URL cannot be empty');
    }

    try {
      final uri = Uri.parse(url);

      if (!uri.hasQuery) {
        throw LinkParsingException('URL does not contain any query parameters');
      }

      final orgId = uri.queryParameters['orgId'];

      if (orgId == null || orgId.isEmpty) {
        throw LinkParsingException('orgId query parameter is missing or empty');
      }

      return orgId;
    } on LinkParsingException {
      rethrow;
    } catch (e) {
      throw LinkParsingException('Failed to parse URL: $e');
    }
  }

  /// Attempts to extract the 'orgId' from a URL, returning null on failure.
  ///
  /// This is a safer variant of [getOrgIdFromLink] that returns null instead
  /// of throwing an exception.
  ///
  /// Example:
  /// ```dart
  /// final orgId = LinkHandler.tryGetOrgIdFromLink(
  ///   'https://my-admin-app.web.app/join?orgId=org-123'
  /// );
  /// if (orgId != null) {
  ///   print('Organization ID: $orgId');
  /// } else {
  ///   print('Could not parse organization ID from URL');
  /// }
  /// ```
  static String? tryGetOrgIdFromLink(String url) {
    try {
      return getOrgIdFromLink(url);
    } catch (e) {
      return null;
    }
  }
}
