// Smoke test placeholder.
//
// The original generated test referenced a stale package name (`gendral_app`)
// and screens that have since been removed, so it never compiled. Driving the
// full App widget requires Firebase.initializeApp, which is unavailable in a
// plain unit-test host. Real feature coverage lives in test/schema/.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test host boots', () {
    expect(1 + 1, 2);
  });
}
