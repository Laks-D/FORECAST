const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Only initialize once (handles hot-reload in emulator).
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// ---------------------------------------------------------------------------
// Utility: send a single FCM message to a user's stored token.
// ---------------------------------------------------------------------------
async function sendFcmToUser(userId, title, body, data = {}) {
  const userDoc = await db.collection("users").doc(userId).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) {
    console.log(`No FCM token for user ${userId}; skipping.`);
    return;
  }

  const message = {
    token,
    notification: { title, body },
    data: { ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    android: {
      priority: "high",
      notification: { channelId: "session_reminders" },
    },
    apns: {
      payload: {
        aps: { alert: { title, body }, badge: 1, sound: "default" },
      },
    },
  };

  try {
    const result = await messaging.send(message);
    console.log(`FCM sent to ${userId}: ${result}`);
    return result;
  } catch (err) {
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      // Remove stale token to avoid repeated failures.
      await db.collection("users").doc(userId).update({ fcmToken: null });
    }
    console.error(`FCM send failed for ${userId}:`, err.message);
    throw err;
  }
}

// ---------------------------------------------------------------------------
// FUNCTION 1: sendScheduledNotification
// Fires immediately when a new scheduledNotifications/{id} doc is created.
// If `sendAt` is in the future, it stores the doc and lets the Pub/Sub
// ticker (processScheduledNotifications) handle it. If sendAt is now/past,
// it sends immediately.
// ---------------------------------------------------------------------------
exports.sendScheduledNotification = functions.firestore
  .document("scheduledNotifications/{id}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { userId, title, body, sendAt, type, payload } = data;

    if (!userId || !title) {
      console.log("Missing required fields; skipping.");
      await snap.ref.update({ sent: false, error: "missing_fields" });
      return;
    }

    const now = Date.now();
    const sendAtMs = sendAt?.toMillis?.() ?? now;

    // If sendAt is more than 30s in the future, let the Pub/Sub ticker handle it.
    if (sendAtMs - now > 30_000) {
      console.log(`Notification ${context.params.id} scheduled for future; skipping onCreate.`);
      return;
    }

    // Send immediately.
    try {
      await sendFcmToUser(userId, title, body, {
        type: type ?? "general",
        ...(payload ?? {}),
      });
      await snap.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
    } catch (err) {
      await snap.ref.update({ sent: false, error: err.message });
    }
  });

// ---------------------------------------------------------------------------
// FUNCTION 2: processScheduledNotifications
// Pub/Sub ticker: runs every 1 minute.
// Polls for unsent notifications that are due.
// ---------------------------------------------------------------------------
exports.processScheduledNotifications = functions.pubsub
  .schedule("every 1 minutes")
  .timeZone("UTC")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("scheduledNotifications")
      .where("sent", "==", false)
      .where("sendAt", "<=", now)
      .limit(100)
      .get();

    if (snap.empty) {
      console.log("No pending notifications.");
      return;
    }

    const batch = db.batch();
    const sends = [];

    snap.forEach((doc) => {
      const { userId, title, body, type, payload } = doc.data();
      if (!userId || !title) {
        // Mark as permanently failed.
        batch.update(doc.ref, {
          sent: false,
          error: "missing_fields",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      sends.push(
        sendFcmToUser(userId, title, body, {
          type: type ?? "general",
          ...(payload ?? {}),
        })
          .then(() =>
            batch.update(doc.ref, {
              sent: true,
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
            })
          )
          .catch((err) =>
            batch.update(doc.ref, {
              sent: false,
              error: err.message,
              processedAt: admin.firestore.FieldValue.serverTimestamp(),
            })
          )
      );
    });

    await Promise.allSettled(sends);
    await batch.commit();
    console.log(`Processed ${sends.length} notification(s).`);
  });

// ---------------------------------------------------------------------------
// FUNCTION 3: scheduleSessionReminders
// Firestore onCreate on users/{tutorId}/sessions/{sessionId}.
// Creates session reminder notifications (2-hour and 5-minute) for both
// the tutor AND the enrolled student.
// ---------------------------------------------------------------------------
exports.scheduleSessionReminders = functions.firestore
  .document("users/{tutorId}/sessions/{sessionId}")
  .onCreate(async (snap, context) => {
    const session = snap.data();
    const { tutorId } = context.params;

    // Parse session date + time into a JS Date.
    const dateParts = session.date?.split("-"); // yyyy-MM-dd
    const timeParts = session.time?.split(":"); // HH:mm
    if (!dateParts || !timeParts || dateParts.length < 3 || timeParts.length < 2) {
      console.log("Invalid date/time on session; skipping reminders.");
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
      console.log("Session is in the past; skipping reminders.");
      return;
    }

    const twoHourBefore = admin.firestore.Timestamp.fromMillis(sessionMs - 2 * 60 * 60 * 1000);
    const fiveMinBefore = admin.firestore.Timestamp.fromMillis(sessionMs - 5 * 60 * 1000);

    const batch = db.batch();

    // --- Tutor reminder ---
    const tutorPayload = {
      type: "session_reminder",
      sessionId: snap.id,
      tutorId,
      clientId: session.clientId ?? "",
    };

    if (sessionMs - now > 2 * 60 * 60 * 1000) {
      batch.set(db.collection("scheduledNotifications").doc(), {
        userId: tutorId,
        title: "Session in 2 hours",
        body: `You have a session (No. ${session.sessionNo ?? "?"}) at ${session.time}.`,
        sendAt: twoHourBefore,
        sent: false,
        type: "session_reminder",
        payload: tutorPayload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (sessionMs - now > 5 * 60 * 1000) {
      batch.set(db.collection("scheduledNotifications").doc(), {
        userId: tutorId,
        title: "Session starting in 5 minutes",
        body: `Your session (No. ${session.sessionNo ?? "?"}) starts soon.`,
        sendAt: fiveMinBefore,
        sent: false,
        type: "session_reminder",
        payload: tutorPayload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // --- Student reminder (find enrolled student via client record) ---
    if (session.clientId) {
      const clientDoc = await db
        .collection("users")
        .doc(tutorId)
        .collection("clients")
        .doc(session.clientId)
        .get();

      const studentUid = clientDoc.data()?.firebaseUid;
      if (studentUid) {
        const studentPayload = { ...tutorPayload, studentId: studentUid };

        if (sessionMs - now > 2 * 60 * 60 * 1000) {
          batch.set(db.collection("scheduledNotifications").doc(), {
            userId: studentUid,
            title: "Session reminder — 2 hours",
            body: `You have a class at ${session.time}. Get ready!`,
            sendAt: twoHourBefore,
            sent: false,
            type: "session_reminder",
            payload: studentPayload,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        if (sessionMs - now > 5 * 60 * 1000) {
          batch.set(db.collection("scheduledNotifications").doc(), {
            userId: studentUid,
            title: "Class starting in 5 minutes!",
            body: `Your class starts at ${session.time}. Be ready!`,
            sendAt: fiveMinBefore,
            sent: false,
            type: "session_reminder",
            payload: studentPayload,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();
    console.log(`Scheduled reminders for session ${snap.id}.`);
  });

// ---------------------------------------------------------------------------
// FUNCTION 4: testNotification (HTTPS callable)
// Manual test trigger for debugging. Sends an immediate FCM to the caller.
// ---------------------------------------------------------------------------
exports.testNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }
  const userId = context.auth.uid;
  const title = data.title ?? "Test Notification";
  const body = data.body ?? "This is a test from Cloud Functions.";

  try {
    await sendFcmToUser(userId, title, body, { type: "test" });
    return { success: true };
  } catch (err) {
    throw new functions.https.HttpsError("internal", err.message);
  }
});

// ---------------------------------------------------------------------------
// FUNCTION 5: schedulePaymentReminders
// Firestore onCreate on users/{tutorId}/clients/{clientId}/timeline/{eventId}
// Sends a payment-due reminder to the student 1 day before the payment date.
// ---------------------------------------------------------------------------
exports.schedulePaymentReminders = functions.firestore
  .document("users/{tutorId}/clients/{clientId}")
  .onUpdate(async (change, context) => {
    const { tutorId, clientId } = context.params;
    const newData = change.after.data();
    const oldData = change.before.data();

    // Detect newly-added payment timeline events.
    const oldTimeline = oldData.timeline ?? [];
    const newTimeline = newData.timeline ?? [];
    if (newTimeline.length <= oldTimeline.length) return; // no new events

    const newEvents = newTimeline.slice(oldTimeline.length);
    const studentUid = newData.firebaseUid;

    const batch = db.batch();

    for (const event of newEvents) {
      if (event.type !== "payment") continue;

      const paymentDate = event.createdAt?.toDate?.();
      if (!paymentDate) continue;

      const now = Date.now();
      const oneDayBefore = new Date(paymentDate.getTime() - 24 * 60 * 60 * 1000);
      if (oneDayBefore.getTime() <= now) continue; // payment already due/past

      const payload = {
        type: "payment_reminder",
        clientId,
        tutorId,
        paymentId: event.id ?? "",
      };

      // Tutor reminder
      batch.set(db.collection("scheduledNotifications").doc(), {
        userId: tutorId,
        title: "Payment due tomorrow",
        body: `Payment of ${newData.currency ?? ""}${event.amount ?? "?"} for ${newData.name ?? "client"} is due tomorrow.`,
        sendAt: admin.firestore.Timestamp.fromDate(oneDayBefore),
        sent: false,
        type: "payment_reminder",
        payload,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Student reminder
      if (studentUid) {
        batch.set(db.collection("scheduledNotifications").doc(), {
          userId: studentUid,
          title: "Payment due tomorrow",
          body: `Your payment of ${newData.currency ?? ""}${event.amount ?? "?"} is due tomorrow.`,
          sendAt: admin.firestore.Timestamp.fromDate(oneDayBefore),
          sent: false,
          type: "payment_reminder",
          payload: { ...payload, studentId: studentUid },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  });
