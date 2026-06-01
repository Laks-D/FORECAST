import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/firebase/firestore_db.dart';

/// Flutter-side helper that writes `scheduledNotifications` docs to Firestore.
/// Cloud Functions (sendScheduledNotification + processScheduledNotifications)
/// pick these up and dispatch actual FCM push messages.
///
/// Field name: `scheduledTime` — matches both the NI app and the updated
/// functions/index.js Pub/Sub query.
class NotificationScheduler {
  NotificationScheduler._();

  static final CollectionReference<Map<String, dynamic>> _col =
      firestoreDb.collection('scheduledNotifications');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Session reminder
  // Writes 2-hour and lead-time notification docs.
  // Cloud Functions also do this automatically on session create — this is the
  // Flutter-side fallback for cases where sessions are rescheduled or created
  // outside of Firestore triggers (e.g., bulk imports).
  // ---------------------------------------------------------------------------
  static Future<void> scheduleSessionReminder({
    required String sessionId,
    required DateTime sessionDate,
    String? clientName,
    String? tutorName,
    int leadMinutes = 5,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    final twoHourBefore = sessionDate.subtract(const Duration(hours: 2));
    final leadBefore = sessionDate.subtract(Duration(minutes: leadMinutes));

    final batch = firestoreDb.batch();

    if (twoHourBefore.isAfter(now)) {
      batch.set(_col.doc(), {
        'userId': uid,
        'title': 'Session in 2 hours',
        'body': clientName != null
            ? 'Session with $clientName at ${_formatTime(sessionDate)}.'
            : 'You have a session at ${_formatTime(sessionDate)}.',
        'scheduledTime': Timestamp.fromDate(twoHourBefore),
        'sent': false,
        'data': {'type': 'session_reminder', 'sessionId': sessionId},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (leadBefore.isAfter(now)) {
      final label = leadMinutes >= 60
          ? '${leadMinutes ~/ 60} hour${leadMinutes >= 120 ? 's' : ''}'
          : '$leadMinutes minutes';
      batch.set(_col.doc(), {
        'userId': uid,
        'title': 'Session in $label',
        'body': clientName != null
            ? 'Session with $clientName is about to start!'
            : 'Your session starts in $label!',
        'scheduledTime': Timestamp.fromDate(leadBefore),
        'sent': false,
        'data': {'type': 'session_reminder', 'sessionId': sessionId},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Payment reminder
  // Notifies [daysBefore] days before a payment is due at [hour]:[minute].
  // ---------------------------------------------------------------------------
  static Future<void> schedulePaymentReminder({
    required String clientId,
    required String clientName,
    required DateTime paymentDue,
    required double amount,
    String? currency,
    String? paymentId,
    int daysBefore = 1,
    int hour = 9,
    int minute = 0,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    final triggerDate = paymentDue.subtract(Duration(days: daysBefore));
    final triggerDateTime = DateTime(
        triggerDate.year, triggerDate.month, triggerDate.day, hour, minute);
    if (!triggerDateTime.isAfter(now)) return;

    final cur = currency ?? '';
    await _col.add({
      'userId': uid,
      'title': daysBefore == 0 ? 'Payment due today' : 'Payment due tomorrow',
      'body':
          'Payment of $cur${amount.toStringAsFixed(0)} for $clientName is due ${daysBefore == 0 ? 'today' : 'tomorrow'}.',
      'scheduledTime': Timestamp.fromDate(triggerDateTime),
      'sent': false,
      'data': {
        'type': 'payment_reminder',
        'clientId': clientId,
        if (paymentId != null) 'paymentId': paymentId,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Generic one-off notification (used by "Test Push Notification" button).
  // ---------------------------------------------------------------------------
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime sendAt,
    String type = 'general',
    Map<String, dynamic> data = const {},
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    if (sendAt.isBefore(now)) return;

    await _col.add({
      'userId': uid,
      'title': title,
      'body': body,
      'scheduledTime': Timestamp.fromDate(sendAt),
      'sent': false,
      'data': {'type': type, ...data},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Cancel pending notifications for a session (call when session is deleted
  // or rescheduled).
  // ---------------------------------------------------------------------------
  static Future<void> cancelSessionNotifications(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;

    final snap = await _col
        .where('userId', isEqualTo: uid)
        .where('sent', isEqualTo: false)
        .where('data.sessionId', isEqualTo: sessionId)
        .get();

    final batch = firestoreDb.batch();
    for (final doc in snap.docs) {
      // Mark as cancelled rather than deleting (for audit trail).
      batch.update(doc.reference, {'sent': true, 'cancelled': true});
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
