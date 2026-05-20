import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns the Firestore instance for the app.
///
/// Uses the default Firestore database `(default)`.
/// Both dev and prod Firebase projects use the default database.
FirebaseFirestore get firestoreDb => FirebaseFirestore.instance;
