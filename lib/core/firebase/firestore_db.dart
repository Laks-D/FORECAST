import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Returns the Firestore instance for the app.
///
/// Uses the configured database id (not `(default)` in this project).
const _databaseId = 'default';

FirebaseFirestore get firestoreDb => FirebaseFirestore.instanceFor(
			app: Firebase.app(),
			databaseId: _databaseId,
		);
