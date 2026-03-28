import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Returns the Firestore database instance the app should use.
///
/// This project is configured with a database ID of `default` (not `(default)`),
/// so we must explicitly target it, otherwise the SDK will try `(default)`.
FirebaseFirestore get firestoreDb {
  return FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
}
