/**
 * Firebase trigger wiring for the admin metrics aggregator (R6.7).
 *
 * Recomputes the four admin counters and writes them to `metrics/global`:
 *   - On any write to `students/{uid}`, `vendors/{uid}`, or `events/{eventId}`
 *     (Firestore document triggers), so the dashboard stays fresh.
 *   - On a fixed schedule (scheduled fallback), so a missed/failed trigger
 *     cannot leave the counters permanently stale.
 *
 * The decision of WHAT the counters mean lives in the pure `counting.ts`
 * module; this file only performs the Firestore reads (using `count()`
 * aggregation queries to avoid downloading every document) and the single write.
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { ACTIVE_STATUS, COMPLETED_STATUS, metricsFromCounts } from "./counting";

const STUDENTS_COLLECTION = "students";
const VENDORS_COLLECTION = "vendors";
const EVENTS_COLLECTION = "events";
const METRICS_DOC_PATH = "metrics/global";

/** How often the scheduled fallback recomputes the counters. */
const FALLBACK_SCHEDULE = "every 60 minutes";

/**
 * Reads the current collection counts via `count()` aggregation queries and
 * writes the recomputed metrics to `metrics/global`.
 *
 * Using server-side aggregation keeps this O(1) in documents transferred
 * regardless of how many students/vendors/events exist.
 */
async function recompute(): Promise<void> {
  const db = getFirestore();

  const studentsCol = db.collection(STUDENTS_COLLECTION);
  const vendorsCol = db.collection(VENDORS_COLLECTION);
  const eventsCol = db.collection(EVENTS_COLLECTION);

  const [studentsSnap, vendorsSnap, activeSnap, completedSnap] =
    await Promise.all([
      studentsCol.count().get(),
      vendorsCol.count().get(),
      eventsCol.where("status", "==", ACTIVE_STATUS).count().get(),
      eventsCol.where("status", "==", COMPLETED_STATUS).count().get(),
    ]);

  const metrics = metricsFromCounts({
    totalStudents: studentsSnap.data().count,
    totalVendors: vendorsSnap.data().count,
    activeEvents: activeSnap.data().count,
    completedEvents: completedSnap.data().count,
  });

  await db.doc(METRICS_DOC_PATH).set(
    {
      ...metrics,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  logger.info("recomputeMetrics: wrote metrics/global", metrics);
}

// --- Firestore document triggers -------------------------------------------
// Any create/update/delete in these collections can change a counter, so each
// recomputes the full snapshot. Recompute is idempotent: writing the same
// counters twice yields the same document.

export const recomputeMetricsOnStudentWrite = onDocumentWritten(
  `${STUDENTS_COLLECTION}/{uid}`,
  async () => {
    await recompute();
  },
);

export const recomputeMetricsOnVendorWrite = onDocumentWritten(
  `${VENDORS_COLLECTION}/{uid}`,
  async () => {
    await recompute();
  },
);

export const recomputeMetricsOnEventWrite = onDocumentWritten(
  `${EVENTS_COLLECTION}/{eventId}`,
  async () => {
    await recompute();
  },
);

// --- Scheduled fallback -----------------------------------------------------
// Guards against a missed/failed document trigger leaving `metrics/global`
// permanently stale.

export const recomputeMetricsScheduled = onSchedule(
  FALLBACK_SCHEDULE,
  async () => {
    await recompute();
  },
);
