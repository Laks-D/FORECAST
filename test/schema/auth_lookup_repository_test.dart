import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow/features/auth/data/username_repository.dart';
import 'package:snow/features/notifications/data/fcm_token_repository.dart';

void main() {
  group('FirestoreUsernameRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreUsernameRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreUsernameRepository(firestore: fake);
    });

    test('register normalizes key and resolves uid', () async {
      await repo.register(uid: 'u1', username: 'Alice Smith!');
      // key normalizes spaces/punct to underscore, lowercased
      expect(await repo.resolveUid('alice_smith'), 'u1');
      expect(await repo.resolveUid('Alice Smith!'), 'u1');
    });

    test('does not overwrite an existing username (no PII stored)', () async {
      await repo.register(uid: 'u1', username: 'bob');
      await repo.register(uid: 'u2', username: 'bob'); // collision -> ignored
      expect(await repo.resolveUid('bob'), 'u1');
      final doc = await fake.collection('usernames').doc('bob').get();
      expect(doc.data()!.containsKey('email'), false);
      expect(doc.data()!.keys.toSet(), {'uid', 'username', 'createdAt'});
    });

    test('resolveUid returns null for unknown', () async {
      expect(await repo.resolveUid('ghost'), isNull);
    });
  });

  group('InMemoryUsernameRepository parity', () {
    test('claims once, resolves', () async {
      final r = InMemoryUsernameRepository();
      await r.register(uid: 'u1', username: 'carol');
      await r.register(uid: 'u2', username: 'carol');
      expect(await r.resolveUid('carol'), 'u1');
    });
  });

  group('FirestoreFcmTokenRepository', () {
    late FakeFirebaseFirestore fake;
    late FirestoreFcmTokenRepository repo;

    setUp(() {
      fake = FakeFirebaseFirestore();
      repo = FirestoreFcmTokenRepository(firestore: fake);
    });

    test('saveToken writes under users/{uid}/fcmTokens', () async {
      await repo.saveToken(uid: 'u1', token: 'tok-abc', platform: 'android');
      final doc = await fake
          .collection('users')
          .doc('u1')
          .collection('fcmTokens')
          .doc('tok-abc')
          .get();
      expect(doc.exists, true);
      expect(doc.data()!['platform'], 'android');
      expect(await repo.getTokens('u1'), ['tok-abc']);
    });

    test('multiple tokens + delete', () async {
      await repo.saveToken(uid: 'u1', token: 't1', platform: 'web');
      await repo.saveToken(uid: 'u1', token: 't2', platform: 'ios');
      expect((await repo.getTokens('u1')).toSet(), {'t1', 't2'});
      await repo.deleteToken(uid: 'u1', token: 't1');
      expect(await repo.getTokens('u1'), ['t2']);
    });

    test('empty uid/token is a safe no-op', () async {
      await repo.saveToken(uid: '', token: 't', platform: 'web');
      await repo.saveToken(uid: 'u1', token: '', platform: 'web');
      expect(await repo.getTokens('u1'), isEmpty);
    });
  });
}
