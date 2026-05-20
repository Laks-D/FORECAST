import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firestore_db.dart';

final selectedOrgProvider = StateProvider<String?>((ref) => null);

/// Fetches organizations owned by the currently signed-in Firebase user.
final organizationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return [];

  final snap = await firestoreDb
      .collection('organizations')
      .where('ownerId', isEqualTo: uid)
      .get();

  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});

/// Fetches students enrolled in the given organization.
final studentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final orgId = ref.watch(selectedOrgProvider);
  if (orgId == null) return [];

  final snap = await firestoreDb
      .collection('organizations')
      .doc(orgId)
      .collection('students')
      .orderBy('fullName')
      .get();

  return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
});
