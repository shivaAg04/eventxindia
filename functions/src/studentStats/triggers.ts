/**
 * Firebase trigger wiring for a student's trusted track-record counters.
 *
 * Recomputes the two counters for ONE student and writes them to
 * `studentStats/{studentId}`:
 *   - On any write to `applications/{applicationId}` (an approval changes how
 *     many events the student has been selected for).
 *   - On any write to `attendance/{attendanceId}` (a check-out completes one).
 *
 * A vendor reviewing an applicant cannot derive these numbers client-side:
 * `attendance` and `applications` reads are scoped per-document to the owning
 * event's vendor (firestore.rules), so a cross-event query by studentId is
 * rejected. This aggregator is therefore the trusted read surface for that
 * track record, mirroring how `metrics/global` serves the admin dashboard.
 *
 * The decision of WHAT the counters mean lives in the pure `counting.ts`
 * module; this file only performs the Firestore reads and the single write.
 *
 * Each trigger recomputes that student's full snapshot rather than
 * incrementing, so it is idempotent: a retried or duplicated delivery yields
 * the same document, and a missed delivery self-heals on the student's next
 * application/attendance write. (There is deliberately no scheduled fallback
 * sweep — unlike the four global `metrics` counters, healing every student
 * would mean walking the whole students collection on a timer.)
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import type { AttendanceState } from "../earnings/accrual";
import {
  APPROVED_STATUS,
  countCompletedAttendance,
  studentStatsFromCounts,
} from "./counting";

const APPLICATIONS_COLLECTION = "applications";
const ATTENDANCE_COLLECTION = "attendance";
const STUDENT_STATS_COLLECTION = "studentStats";

/**
 * Recomputes and stores `studentStats/{studentId}`.
 *
 * Approved applications are tallied with a server-side `count()` aggregation
 * (O(1) in documents transferred, using the existing studentId+status index).
 * Attendance needs the completed predicate, which no single Firestore filter
 * expresses — Firestore permits only one inequality field per query — so it
 * uses a projection query that transfers just the two timestamp fields.
 */
async function recomputeFor(studentId: string): Promise<void> {
  if (studentId.length === 0) {
    logger.warn("recomputeStudentStats: empty studentId; skipping");
    return;
  }
  const db = getFirestore();

  const [approvedSnap, attendanceSnap] = await Promise.all([
    db
      .collection(APPLICATIONS_COLLECTION)
      .where("studentId", "==", studentId)
      .where("status", "==", APPROVED_STATUS)
      .count()
      .get(),
    db
      .collection(ATTENDANCE_COLLECTION)
      .where("studentId", "==", studentId)
      .select("checkInTime", "checkOutTime")
      .get(),
  ]);

  const states: AttendanceState[] = attendanceSnap.docs.map((doc) => {
    const data = doc.data();
    return {
      hasCheckIn: data.checkInTime != null,
      hasCheckOut: data.checkOutTime != null,
      // Irrelevant to the completed predicate; earnings owns this marker.
      accrued: false,
    };
  });

  const stats = studentStatsFromCounts({
    studentId,
    eventsParticipated: approvedSnap.data().count,
    attendanceCompleted: countCompletedAttendance(states),
  });

  await db
    .collection(STUDENT_STATS_COLLECTION)
    .doc(studentId)
    .set(
      {
        ...stats,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  logger.info("recomputeStudentStats: wrote studentStats", stats);
}

/**
 * Resolves the studentId a write concerns, from whichever of the before/after
 * snapshots exists (a delete has no `after`).
 */
function studentIdOf(event: {
  data?: {
    before?: { data(): Record<string, unknown> | undefined };
    after?: { data(): Record<string, unknown> | undefined };
  };
}): string | null {
  const after = event.data?.after?.data();
  const before = event.data?.before?.data();
  const raw = after?.studentId ?? before?.studentId;
  return typeof raw === "string" && raw.length > 0 ? raw : null;
}

// --- Firestore document triggers -------------------------------------------
// Any create/update/delete on one of these documents can move a counter for
// exactly one student, so each recomputes that student's snapshot.

export const recomputeStudentStatsOnApplicationWrite = onDocumentWritten(
  `${APPLICATIONS_COLLECTION}/{applicationId}`,
  async (event) => {
    const studentId = studentIdOf(event);
    if (studentId === null) {
      logger.warn("recomputeStudentStats: application write without studentId");
      return;
    }
    await recomputeFor(studentId);
  },
);

export const recomputeStudentStatsOnAttendanceWrite = onDocumentWritten(
  `${ATTENDANCE_COLLECTION}/{attendanceId}`,
  async (event) => {
    const studentId = studentIdOf(event);
    if (studentId === null) {
      logger.warn("recomputeStudentStats: attendance write without studentId");
      return;
    }
    await recomputeFor(studentId);
  },
);
