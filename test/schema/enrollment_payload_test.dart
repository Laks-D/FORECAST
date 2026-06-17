import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/join_request/enrollment_payload.dart';

void main() {
  group('buildEnrollmentPayload (Phase 7 enrichment)', () {
    test('QR accept payload carries source + studentUid + joinRequestId', () {
      final p = buildEnrollmentPayload(
        tutorId: 't1',
        studentUid: 's1',
        tutorName: 'Mr Tutor',
        source: 'qr',
        joinRequestId: 'jr1',
      );
      expect(p['tutorId'], 't1');
      expect(p['studentUid'], 's1');
      expect(p['source'], 'qr');
      expect(p['joinRequestId'], 'jr1');
      expect(p['status'], 'enrolled'); // unchanged default -> existing readers OK
    });

    test('orphan self-enroll omits joinRequestId, sets source', () {
      final p = buildEnrollmentPayload(
        tutorId: 't1',
        studentUid: 's1',
        source: 'orphan_match',
      );
      expect(p.containsKey('joinRequestId'), false);
      expect(p['source'], 'orphan_match');
      expect(p['studentUid'], 's1');
    });

    test('defaults are backward compatible', () {
      final p = buildEnrollmentPayload(tutorId: 't', studentUid: 's');
      expect(p['source'], 'qr');
      expect(p['status'], 'enrolled');
      expect(p['tutorName'], '');
    });
  });
}
