const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Only initialise once (safe for emulator hot-reload).
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Utility: look up a user's FCM token and send them a push notification.
// Mirrors NI's sendNotificationToUser helper exactly.
// ---------------------------------------------------------------------------
async function sendNotificationToUser(userId, title, body, data) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData || !userData.fcmToken) {
      console.log('No FCM token found for user:', userId);
      return;
    }

    const message = {
      notification: { title, body },
      data: data || {},
      token: userData.fcmToken,
      android: {
        notification: {
          channelId: 'session_channel_v5',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    // Remove stale tokens to prevent repeated failures.
    if (
      error.code === 'messaging/registration-token-not-registered' ||
      error.code === 'messaging/invalid-registration-token'
    ) {
      await db.collection('users').doc(userId).update({ fcmToken: null });
      console.log('Cleared stale FCM token for user:', userId);
    }
    console.error('Error sending message:', error);
    throw error;
  }
}

// ---------------------------------------------------------------------------
// FUNCTION 1: sendScheduledNotification
// Firestore onCreate on scheduledNotifications/{notificationId}.
// Fires immediately when a new notification doc is created.
// If scheduledTime is in the future (> 30s), the Pub/Sub ticker handles it.
// Mirrors NI's sendScheduledNotification function.
// ---------------------------------------------------------------------------
exports.sendScheduledNotification = functions.firestore
  .document('scheduledNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const { userId, title, body, scheduledTime, data, sent } = notification;

    // Skip if already processed.
    if (sent) {
      console.log('Notification already sent, skipping...');
      return null;
    }

    if (!userId || !title) {
      console.log('Missing required fields; skipping.');
      await snap.ref.update({ sent: false, error: 'missing_fields' });
      return null;
    }

    // Check if it's time to send.
    const now = admin.firestore.Timestamp.now();
    const scheduleTime = scheduledTime;

    if (scheduleTime && scheduleTime.toMillis() - now.toMillis() > 30_000) {
      console.log('Notification scheduled for future; Pub/Sub ticker will handle it.');
      return null;
    }

    // Send immediately.
    try {
      await sendNotificationToUser(userId, title, body, data || {});
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('Notification sent successfully');
    } catch (error) {
      console.error('Error sending notification:', error);
      await snap.ref.update({ sent: false, error: error.message });
    }

    return null;
  });

// ---------------------------------------------------------------------------
// FUNCTION 2: processScheduledNotifications
// Pub/Sub ticker: runs every 1 minute.
// Polls Firestore for any unsent notifications that are due.
// Mirrors NI's processScheduledNotifications function.
// ---------------------------------------------------------------------------
exports.processScheduledNotifications = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // Query for notifications that are due to be sent.
    const query = db
      .collection('scheduledNotifications')
      .where('sent', '==', false)
      .where('scheduledTime', '<=', now)
      .limit(50);

    const snapshot = await query.get();

    if (snapshot.empty) {
      console.log('No scheduled notifications to process');
      return null;
    }

    const batch = db.batch();
    const notifications = [];

    snapshot.forEach(doc => {
      const notification = doc.data();
      notifications.push({ id: doc.id, ...notification });

      // Mark as sent in batch.
      batch.update(doc.ref, {
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Send all notifications.
    const promises = notifications.map(notification =>
      sendNotificationToUser(
        notification.userId,
        notification.title,
        notification.body,
        notification.data || {}
      )
    );

    try {
      await Promise.allSettled(promises);
      await batch.commit();
      console.log(`Successfully processed ${notifications.length} scheduled notifications`);
    } catch (error) {
      console.error('Error processing scheduled notifications:', error);
    }

    return null;
  });

// ---------------------------------------------------------------------------
// FUNCTION 3: testNotification (HTTPS callable)
// Manual test trigger. Sends an immediate push to the authenticated caller.
// Mirrors NI's testNotification function.
// ---------------------------------------------------------------------------
exports.testNotification = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { title, body } = data;
  const userId = context.auth.uid;

  try {
    await sendNotificationToUser(
      userId,
      title || 'Test Notification',
      body || 'This is a test push notification from Cloud Functions!',
      { type: 'test' }
    );
    return { success: true, message: 'Test notification sent successfully' };
  } catch (error) {
    console.error('Test notification failed:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send test notification');
  }
});

// ---------------------------------------------------------------------------
// FUNCTION 4: scheduleSessionReminders
// Firestore onCreate on users/{tutorId}/sessions/{sessionId}.
// Auto-schedules 2-hour and 5-minute reminders for both tutor and student.
// ---------------------------------------------------------------------------
exports.scheduleSessionReminders = functions.firestore
  .document('users/{tutorId}/sessions/{sessionId}')
  .onCreate(async (snap, context) => {
    const session = snap.data();
    const { tutorId } = context.params;

    // Parse session date + time into a JS Date.
    const dateParts = session.date && session.date.split('-'); // yyyy-MM-dd
    const timeParts = session.time && session.time.split(':');  // HH:mm
    if (!dateParts || !timeParts || dateParts.length < 3 || timeParts.length < 2) {
      console.log('Invalid date/time on session; skipping reminders.');
      return;
    }

    const sessionDate = new Date(
      parseInt(dateParts[0]),
      parseInt(dateParts[1]) - 1,
      parseInt(dateParts[2]),
      parseInt(timeParts[0]),
      parseInt(timeParts[1])
    );
    const sessionMs = sessionDate.getTime();
    const now = Date.now();

    if (sessionMs <= now) {
      console.log('Session is in the past; skipping reminders.');
      return;
    }

    const twoHourBefore = admin.firestore.Timestamp.fromMillis(sessionMs - 2 * 60 * 60 * 1000);
    const fiveMinBefore  = admin.firestore.Timestamp.fromMillis(sessionMs - 5 * 60 * 1000);

    const batch = db.batch();
    const basePayload = {
      type: 'session_reminder',
      sessionId: snap.id,
      tutorId,
      clientId: session.clientId || '',
    };

    // --- Tutor reminders ---
    if (sessionMs - now > 2 * 60 * 60 * 1000) {
      batch.set(db.collection('scheduledNotifications').doc(), {
        userId: tutorId,
        title: 'Session in 2 hours',
        body: `You have a session (No. ${session.sessionNo || '?'}) at ${session.time}.`,
        scheduledTime: twoHourBefore,
        sent: false,
        data: basePayload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (sessionMs - now > 5 * 60 * 1000) {
      batch.set(db.collection('scheduledNotifications').doc(), {
        userId: tutorId,
        title: 'Session starting in 5 minutes',
        body: `Your session (No. ${session.sessionNo || '?'}) starts very soon.`,
        scheduledTime: fiveMinBefore,
        sent: false,
        data: basePayload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // --- Student reminders (if enrolled student has a linked UID) ---
    if (session.clientId) {
      try {
        const clientDoc = await db
          .collection('users')
          .doc(tutorId)
          .collection('clients')
          .doc(session.clientId)
          .get();

        const studentUid = clientDoc.data() && clientDoc.data().firebaseUid;
        if (studentUid) {
          const studentPayload = { ...basePayload, studentId: studentUid };

          if (sessionMs - now > 2 * 60 * 60 * 1000) {
            batch.set(db.collection('scheduledNotifications').doc(), {
              userId: studentUid,
              title: 'Session reminder — 2 hours',
              body: `You have a class at ${session.time}. Get ready!`,
              scheduledTime: twoHourBefore,
              sent: false,
              data: studentPayload,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          if (sessionMs - now > 5 * 60 * 1000) {
            batch.set(db.collection('scheduledNotifications').doc(), {
              userId: studentUid,
              title: 'Class starting in 5 minutes!',
              body: `Your class starts at ${session.time}. Be ready!`,
              scheduledTime: fiveMinBefore,
              sent: false,
              data: studentPayload,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (err) {
        console.error('Error looking up student UID for session reminders:', err);
      }
    }

    await batch.commit();
    console.log(`Scheduled reminders for session ${snap.id}.`);
    return null;
  });

// ---------------------------------------------------------------------------
// FUNCTION 5: schedulePaymentReminders
// Firestore onUpdate on users/{tutorId}/clients/{clientId}.
// Detects newly added payment timeline events and schedules reminders.
// ---------------------------------------------------------------------------
exports.schedulePaymentReminders = functions.firestore
  .document('users/{tutorId}/clients/{clientId}')
  .onUpdate(async (change, context) => {
    const { tutorId, clientId } = context.params;
    const newData = change.after.data();
    const oldData = change.before.data();

    // Detect newly-added payment events.
    const oldTimeline = oldData.timeline || [];
    const newTimeline = newData.timeline || [];
    if (newTimeline.length <= oldTimeline.length) return; // no new events

    const newEvents = newTimeline.slice(oldTimeline.length);
    const studentUid = newData.firebaseUid;

    const batch = db.batch();

    for (const event of newEvents) {
      if (event.type !== 'payment') continue;

      const paymentDate = event.createdAt && event.createdAt.toDate
        ? event.createdAt.toDate()
        : null;
      if (!paymentDate) continue;

      const now = Date.now();
      const oneDayBefore = new Date(paymentDate.getTime() - 24 * 60 * 60 * 1000);
      if (oneDayBefore.getTime() <= now) continue; // already past

      const payload = {
        type: 'payment_reminder',
        clientId,
        tutorId,
        paymentId: event.id || '',
      };

      // Tutor reminder.
      batch.set(db.collection('scheduledNotifications').doc(), {
        userId: tutorId,
        title: 'Payment due tomorrow',
        body: `Payment of ${newData.currency || ''}${event.amount || '?'} for ${newData.name || 'client'} is due tomorrow.`,
        scheduledTime: admin.firestore.Timestamp.fromDate(oneDayBefore),
        sent: false,
        data: payload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Student reminder.
      if (studentUid) {
        batch.set(db.collection('scheduledNotifications').doc(), {
          userId: studentUid,
          title: 'Payment due tomorrow',
          body: `Your payment of ${newData.currency || ''}${event.amount || '?'} is due tomorrow.`,
          scheduledTime: admin.firestore.Timestamp.fromDate(oneDayBefore),
          sent: false,
          data: { ...payload, studentId: studentUid },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return null;
  });
