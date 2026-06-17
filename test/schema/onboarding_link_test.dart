import 'package:flutter_test/flutter_test.dart';
import 'package:snow/utils/app_links.dart';

void main() {
  group('OnboardingLink.parse', () {
    test('full invite URL', () {
      final (tutor, ts) = OnboardingLink.parse(
          'https://genericapp-prod.web.app/join?tutorId=abc123&ts=1700000000000');
      expect(tutor, 'abc123');
      expect(ts, '1700000000000');
    });

    test('query-string only (pasted code)', () {
      final (tutor, ts) = OnboardingLink.parse('tutorId=xyz&ts=999');
      expect(tutor, 'xyz');
      expect(ts, '999');
    });

    test('bare tutorId (no ts)', () {
      final (tutor, ts) = OnboardingLink.parse('justTheUid28chars');
      expect(tutor, 'justTheUid28chars');
      expect(ts, isNull);
    });

    test('whitespace is trimmed', () {
      final (tutor, _) = OnboardingLink.parse('   tutorId=trimmed&ts=1   ');
      expect(tutor, 'trimmed');
    });

    test('empty / garbage URL yields nulls', () {
      expect(OnboardingLink.parse('').$1, isNull);
      expect(OnboardingLink.parse('https://example.com/no-params').$1, isNull);
      expect(OnboardingLink.parse('a b/c?d').$1, isNull);
    });

    test('round-trips a generated link', () {
      final link = OnboardingLink.generateLink('uid-42', '1234567890');
      final (tutor, ts) = OnboardingLink.parse(link);
      expect(tutor, 'uid-42');
      expect(ts, '1234567890');
    });

    test('legacy helpers still work', () {
      const url = 'https://x/join?tutorId=L&ts=7';
      expect(OnboardingLink.parseTutorId(url), 'L');
      expect(OnboardingLink.parseTimestamp(url), '7');
    });
  });
}
