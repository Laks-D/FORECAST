import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/firebase/firestore_db.dart';

/// Flutter-side helper that writes `scheduledNotifications` docs to Firestore.
/// Cloud Functions pick these up and dispatch the actual FCM messages.
///
/// Usage:
///   await NotificationScheduler.scheduleSessionReminder(
///     sessionId: '123',
///     sessionDate: DateTime(2026, 6, 5, 10, 0),
///     clientName: 'Arjun',
///   );
class NotificationScheduler {
  NotificationScheduler._();

  static final CollectionReference<Map<String, dynamic>> _col =
      firestoreDb.collection('scheduledNotifications');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Session reminder: creates 2-hour and 5-minute notification docs.
  // Cloud Functions' scheduleSessionReminders trigger does this automatically
  // on session create; this method is the Flutter-side fallback for cases
  // where a session is created or rescheduled outside of Firestore triggers.
  // ---------------------------------------------------------------------------
  static Future<void> scheduleSessionReminder({
    required String sessionId,
    required DateTime sessionDate,
    String? clientName,
    String? tutorName,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    final twoHourBefore = sessionDate.subtract(const Duration(hours: 2));
    final fiveMinBefore = sessionDate.subtract(const Duration(minutes: 5));

    final batch = firestoreDb.batch();

    if (twoHourBefore.isAfter(now)) {
      batch.set(_col.doc(), {
        'userId': uid,
        'title': 'Session in 2 hours',
        'body': clientName != null
            ? 'Session with $clientName at ${_formatTime(sessionDate)}.'
            : 'You have a session at ${_formatTime(sessionDate)}.',
        'sendAt': Timestamp.fromDate(twoHourBefore),
        'sent': false,
        'type': 'session_reminder',
        'payload': {'sessionId': sessionId},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (fiveMinBefore.isAfter(now)) {
      batch.set(_col.doc(), {
        'userId': uid,
        'title': 'Session starting in 5 minutes',
        'body': clientName != null
            ? 'Session with $clientName is about to start!'
            : 'Your session starts in 5 minutes!',
        'sendAt': Timestamp.fromDate(fiveMinBefore),
        'sent': false,
        'type': 'session_reminder',
        'payload': {'sessionId': sessionId},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Payment reminder: notifies the user 1 day before a payment is due.
  // ---------------------------------------------------------------------------
  static Future<void> schedulePaymentReminder({
    required String clientId,
    required String clientName,
    required DateTime paymentDue,
    required double amount,
    String? currency,
    String? paymentId,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    final oneDayBefore = paymentDue.subtract(const Duration(days: 1));
    if (!oneDayBefore.isAfter(now)) return; // already past

    final cur = currency ?? '';
    await _col.add({
      'userId': uid,
      'title': 'Payment due tomorrow',
      'body': 'Payment of $cur${amount.toStringAsFixed(0)} for $clientName is due tomorrow.',
      'sendAt': Timestamp.fromDate(oneDayBefore),
      'sent': false,
      'type': 'payment_reminder',
      'payload': {
        'clientId': clientId,
        if (paymentId != null) 'paymentId': paymentId,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Generic one-off notification.
  // ---------------------------------------------------------------------------
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime sendAt,
    String type = 'general',
    Map<String, dynamic> payload = const {},
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    if (sendAt.isBefore(now)) return;

    await _col.add({
      'userId': uid,
      'title': title,
      'body': body,
      'sendAt': Timestamp.fromDate(sendAt),
      'sent': false,
      'type': type,
      'payload': payload,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Cancel pending notifications for a session (e.g., when session is deleted).
  // ---------------------------------------------------------------------------
  static Future<void> cancelSessionNotifications(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;

    final snap = await _col
        .where('userId', isEqualTo: uid)
        .where('sent', isEqualTo: false)
        .where('payload.sessionId', isEqualTo: sessionId)
        .get();

    final batch = firestoreDb.batch();
    for (final doc in snap.docs) {
      // Mark as cancelled rather than deleting (for audit trail).
      batch.update(doc.reference, {'sent': true, 'cancelled': true});
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Store/update the FCM token for this device.
  // Called from NotificationCubit when the token is obtained/refreshed.
  // ---------------------------------------------------------------------------
  static Future<void> saveFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await firestoreDb.collection('users').doc(uid).update({'fcmToken': token});
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
