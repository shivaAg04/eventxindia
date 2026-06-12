/**
 * Firebase trigger wiring for the NotificationService capability (R13).
 *
 * Four Cloud Functions, each delegating its *decision* to a PURE, property-
 * tested module (`./creation`, `./reminders`, `./delivery`) and performing only
 * the Firestore reads/writes and FCM dispatch here:
 *
 *   - `onApplicationCreated`      onCreate applications/{id} -> NewApplication
 *                                 to the owning vendor (R13.4).
 *   - `onApplicationStatusChange` onUpdate applications/{id} -> Approved/Rejected
 *                                 notice to the applicant (R13.1, R13.2).
 *   - `eventReminders`            scheduled -> EventReminder to each student with
 *                                 an Approved application for an event starting
 *                                 within 24h, deduped (R13.3).
 *   - `deliverNotification`       onCreate notifications/{id} -> FCM dispatch
 *                                 with skip / ≤3 attempts ≥60s apart / Failed
 *                                 after exhaustion, preserving trigger data
 *                                 (R13.5–R13.8).
 */
import {
  getFirestore,
  FieldValue,
  Timestamp,
  DocumentData,
  Firestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

import {
  ApplicationFacts,
  ApplicationStatus,
  NotificationToCreate,
  notificationForCreatedApplication,
  notificationForStatusChange,
} from "./creation";
import {
  ApprovedApplication,
  ReminderEvent,
  REMINDER_WINDOW_MS,
  reminderKey,
  selectReminderRecipients,
} from "./reminders";
import {
  MAX_ATTEMPTS,
  MIN_RETRY_INTERVAL_MS,
  decideDelivery,
} from "./delivery";

// --- Collection names (single source of truth for these triggers) ----------
const APPLICATIONS_COLLECTION = "applications";
const EVENTS_COLLECTION = "events";
const USERS_COLLECTION = "users";
const NOTIFICATIONS_COLLECTION = "notifications";

const APPROVED_STATUS: ApplicationStatus = "Approved";
const REMINDER_TYPE = "EventReminder";

/** How often the reminder sweep runs. */
const REMINDER_SCHEDULE = "every 60 minutes";

/**
 * Persist a decided notification to `notifications/{id}` in the Pending state.
 *
 * `deliveryStatus`/`attemptCount` start the delivery state machine; the
 * `deliverNotification` trigger drives them to a terminal state. The payload is
 * the preserved "triggering event data" referenced by R13.8.
 */
async function createNotification(
  db: Firestore,
  notification: NotificationToCreate,
): Promise<void> {
  const ref = db.collection(NOTIFICATIONS_COLLECTION).doc();
  await ref.set({
    notificationId: ref.id,
    recipientId: notification.recipientId,
    type: notification.type,
    payload: notification.payload,
    deliveryStatus: "Pending",
    attemptCount: 0,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/** Extracts the application identity fields from a Firestore doc. */
function toApplicationFacts(
  id: string,
  data: DocumentData | undefined,
): ApplicationFacts | null {
  if (data === undefined) {
    return null;
  }
  const eventId = data.eventId;
  const studentId = data.studentId;
  if (
    typeof eventId !== "string" ||
    eventId.length === 0 ||
    typeof studentId !== "string" ||
    studentId.length === 0
  ) {
    return null;
  }
  const applicationId =
    typeof data.applicationId === "string" && data.applicationId.length > 0
      ? data.applicationId
      : id;
  return { applicationId, eventId, studentId };
}

// --- onApplicationCreated (R13.4) ------------------------------------------
export const onApplicationCreated = onDocumentCreated(
  `${APPLICATIONS_COLLECTION}/{id}`,
  async (event) => {
    const facts = toApplicationFacts(event.params.id, event.data?.data());
    if (facts === null) {
      logger.warn("onApplicationCreated: malformed application; skipping", {
        id: event.params.id,
      });
      return;
    }

    const db = getFirestore();
    const eventSnap = await db
      .collection(EVENTS_COLLECTION)
      .doc(facts.eventId)
      .get();
    const vendorId = eventSnap.get("vendorId");
    if (typeof vendorId !== "string" || vendorId.length === 0) {
      logger.warn("onApplicationCreated: event/vendor missing; skipping", {
        eventId: facts.eventId,
      });
      return;
    }

    await createNotification(
      db,
      notificationForCreatedApplication(facts, vendorId),
    );
  },
);

// --- onApplicationStatusChange (R13.1, R13.2) ------------------------------
export const onApplicationStatusChange = onDocumentUpdated(
  `${APPLICATIONS_COLLECTION}/{id}`,
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();
    const facts = toApplicationFacts(event.params.id, afterData);
    if (facts === null || beforeData === undefined) {
      return;
    }

    const before = beforeData.status as ApplicationStatus;
    const after = afterData?.status as ApplicationStatus;

    const notification = notificationForStatusChange(facts, before, after);
    if (notification === null) {
      return;
    }

    await createNotification(getFirestore(), notification);
  },
);

// --- eventReminders (R13.3) -------------------------------------------------
export const eventReminders = onSchedule(REMINDER_SCHEDULE, async () => {
  const db = getFirestore();
  const nowMs = Date.now();
  const windowEnd = Timestamp.fromMillis(nowMs + REMINDER_WINDOW_MS);
  const windowStart = Timestamp.fromMillis(nowMs);

  // Events whose start falls inside the 24h reminder window.
  const eventsSnap = await db
    .collection(EVENTS_COLLECTION)
    .where("startTime", ">=", windowStart)
    .where("startTime", "<=", windowEnd)
    .get();

  const events: ReminderEvent[] = [];
  for (const doc of eventsSnap.docs) {
    const start = doc.get("startTime");
    if (start instanceof Timestamp) {
      events.push({ eventId: doc.id, startTimeMs: start.toMillis() });
    }
  }
  if (events.length === 0) {
    return;
  }

  // Approved applications (filtered to the due events by the pure selector).
  const approvedSnap = await db
    .collection(APPLICATIONS_COLLECTION)
    .where("status", "==", APPROVED_STATUS)
    .get();
  const approvedApplications: ApprovedApplication[] = [];
  for (const doc of approvedSnap.docs) {
    const eventId = doc.get("eventId");
    const studentId = doc.get("studentId");
    if (typeof eventId === "string" && typeof studentId === "string") {
      approvedApplications.push({ eventId, studentId });
    }
  }

  // Reminders already created, so we never send the same one twice.
  const sentSnap = await db
    .collection(NOTIFICATIONS_COLLECTION)
    .where("type", "==", REMINDER_TYPE)
    .get();
  const alreadySentKeys = new Set<string>();
  for (const doc of sentSnap.docs) {
    const recipientId = doc.get("recipientId");
    const eventId = doc.get("payload.eventId");
    if (typeof recipientId === "string" && typeof eventId === "string") {
      alreadySentKeys.add(reminderKey(recipientId, eventId));
    }
  }

  const recipients = selectReminderRecipients({
    events,
    approvedApplications,
    alreadySentKeys,
    nowMs,
  });

  await Promise.all(
    recipients.map((r) =>
      createNotification(db, {
        type: "EventReminder",
        recipientId: r.studentId,
        payload: {
          eventId: r.eventId,
          title: "Event reminder",
          body: "Your event starts within 24 hours.",
        },
      }),
    ),
  );

  logger.info("eventReminders: created reminders", {
    count: recipients.length,
  });
});

// --- deliverNotification (R13.5–R13.8) -------------------------------------

/** Resolves after `ms` milliseconds (used to space retries ≥60s apart). */
function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Reads the recipient's registered FCM device tokens (empty if none). */
async function readDeviceTokens(
  db: Firestore,
  recipientId: string,
): Promise<string[]> {
  const snap = await db.collection(USERS_COLLECTION).doc(recipientId).get();
  const tokens = snap.get("deviceTokens");
  if (!Array.isArray(tokens)) {
    return [];
  }
  return tokens.filter((t): t is string => typeof t === "string" && t.length > 0);
}

/**
 * Attempts a single FCM multicast send. Returns true if at least one token
 * accepted the message. Any thrown transport error is treated as a failed
 * attempt (returns false) so the retry budget governs the outcome.
 */
async function attemptSend(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
    });
    return response.successCount > 0;
  } catch (err) {
    logger.warn("deliverNotification: FCM send threw", { err });
    return false;
  }
}

export const deliverNotification = onDocumentCreated(
  // Allow enough wall-clock time for up to 2 retries spaced ≥60s apart.
  { document: `${NOTIFICATIONS_COLLECTION}/{id}`, timeoutSeconds: 300 },
  async (event) => {
    const snap = event.data;
    const data = snap?.data();
    if (snap === undefined || data === undefined) {
      return;
    }

    const db = getFirestore();
    const ref = snap.ref;
    const recipientId = data.recipientId as string;
    const payload = (data.payload ?? {}) as {
      title?: string;
      body?: string;
      eventId?: string;
      applicationId?: string;
    };

    const tokens = await readDeviceTokens(db, recipientId);

    // R13.7: no registered device token -> skip without error or retries.
    if (tokens.length === 0) {
      await ref.update({ deliveryStatus: "Skipped" });
      logger.info("deliverNotification: skipped (no device token)", {
        notificationId: ref.id,
      });
      return;
    }

    // FCM data values must be strings; preserve the triggering data (R13.8).
    const fcmData: Record<string, string> = {};
    if (payload.eventId) fcmData.eventId = payload.eventId;
    if (payload.applicationId) fcmData.applicationId = payload.applicationId;
    const title = payload.title ?? "Notification";
    const body = payload.body ?? "";

    let attemptCount = 0;
    let lastAttemptAtMs: number | null = null;

    // Retry loop bounded by the pure delivery decision: ≤3 attempts, ≥60s apart.
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const decision = decideDelivery({
        hasDeviceToken: true,
        attemptCount,
        lastAttemptAtMs,
        nowMs: Date.now(),
      });

      if (decision === "wait") {
        const waitMs =
          MIN_RETRY_INTERVAL_MS - (Date.now() - (lastAttemptAtMs ?? 0));
        await delay(Math.max(0, waitMs));
        continue;
      }

      if (decision === "fail") {
        // R13.8: exhausted all attempts — record Failed; payload (the
        // triggering data) is left intact on the document.
        await ref.update({
          deliveryStatus: "Failed",
          attemptCount,
          lastAttemptAt: FieldValue.serverTimestamp(),
        });
        logger.warn("deliverNotification: failed after retries", {
          notificationId: ref.id,
          attemptCount,
        });
        return;
      }

      // decision === "deliver"
      attemptCount += 1;
      lastAttemptAtMs = Date.now();
      const delivered = await attemptSend(tokens, title, body, fcmData);

      if (delivered) {
        await ref.update({
          deliveryStatus: "Delivered",
          attemptCount,
          lastAttemptAt: Timestamp.fromMillis(lastAttemptAtMs),
        });
        logger.info("deliverNotification: delivered", {
          notificationId: ref.id,
          attemptCount,
        });
        return;
      }

      // Record the failed attempt so the state survives even if this
      // invocation is interrupted before the loop reaches a terminal state.
      await ref.update({
        attemptCount,
        lastAttemptAt: Timestamp.fromMillis(lastAttemptAtMs),
      });

      if (attemptCount >= MAX_ATTEMPTS) {
        await ref.update({ deliveryStatus: "Failed" });
        logger.warn("deliverNotification: failed after retries", {
          notificationId: ref.id,
          attemptCount,
        });
        return;
      }
    }
  },
);
