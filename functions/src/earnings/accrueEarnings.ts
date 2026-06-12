/**
 * Trusted, exactly-once earnings accrual Cloud Function (R11.1, R11.2).
 *
 * Triggered on every write to `attendance/{id}`. When an attendance record
 * becomes *completed* (has both a check-in and a check-out time) and has not
 * yet been accrued, the function credits the owning event's `payPerHead` to the
 * student's `earnings/{studentId}` document — exactly once.
 *
 * Exactly-once is guaranteed by an idempotency marker (`attendance.accrued`)
 * that is read AND written inside a single Firestore transaction:
 *   1. Re-read the attendance doc inside the transaction.
 *   2. If it is no longer completed, or already `accrued`, do nothing.
 *   3. Otherwise atomically (a) increment `earnings/{studentId}.total` and
 *      `earnings/{studentId}.perEvent[eventId]` by `payPerHead`, and
 *      (b) set `attendance/{id}.accrued = true`.
 * Because the marker flip and the credit commit together, a duplicate or
 * retried trigger that observes `accrued === true` is a no-op.
 *
 * The pure decision/reduction logic lives in `./accrual` so it can be
 * property-tested with `fast-check` (task 27.2) independently of Firebase. The
 * `accrued` field is never writable by clients (security rules / DTO), so this
 * function is the sole writer of earnings.
 *
 * Money is stored in exact integer minor units (paise): the event document's
 * `payPerHead` and the earnings `total`/`perEvent` values all use the same
 * representation, keeping accrual free of floating-point drift.
 */
import { getFirestore, FieldValue, DocumentData } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

import { AttendanceState, shouldAccrue } from "./accrual";

/** Firestore collection names (single source of truth for this trigger). */
const ATTENDANCE_COLLECTION = "attendance";
const EARNINGS_COLLECTION = "earnings";
const EVENTS_COLLECTION = "events";

/** Builds the presence-only attendance view the pure decision needs. */
function toAttendanceState(
  data: DocumentData | undefined,
): AttendanceState | null {
  if (data === undefined) {
    return null;
  }
  return {
    hasCheckIn: data.checkInTime != null,
    hasCheckOut: data.checkOutTime != null,
    accrued: data.accrued === true,
  };
}

/**
 * Reads the event's `payPerHead` (integer paise). Returns `null` when the event
 * or its pay is missing/invalid, so the caller can skip accrual rather than
 * credit a bogus amount.
 */
function readPayPerHeadPaise(
  data: DocumentData | undefined,
): number | null {
  if (data === undefined) {
    return null;
  }
  const raw = data.payPerHead;
  if (typeof raw !== "number" || !Number.isInteger(raw) || raw < 0) {
    return null;
  }
  return raw;
}

/**
 * Converts an integer paise amount to a decimal major-unit (rupee) value.
 *
 * Earnings are persisted as `decimal` major units in `earnings/{studentId}`
 * (design "Data Models"), matching how the Flutter client's `MoneyMapper`
 * reads them. The event document stores `payPerHead` in integer paise, so the
 * accrual converts to major units before crediting. Division by 100 is exact
 * for paise amounts within the supported range.
 */
function paiseToMajorUnits(paise: number): number {
  return paise / 100;
}

export const accrueEarnings = onDocumentWritten(
  `${ATTENDANCE_COLLECTION}/{id}`,
  async (event) => {
    const attendanceId = event.params.id;

    // Fast pre-check against the trigger snapshot. The authoritative check is
    // re-run inside the transaction below; this just avoids opening a
    // transaction for the common no-op writes (check-in only, deletes, writes
    // that arrive after the record was already accrued).
    const afterData = event.data?.after?.data();
    if (!shouldAccrue(toAttendanceState(afterData))) {
      return;
    }

    const eventId = afterData?.eventId as string | undefined;
    const studentId = afterData?.studentId as string | undefined;
    if (
      typeof eventId !== "string" ||
      eventId.length === 0 ||
      typeof studentId !== "string" ||
      studentId.length === 0
    ) {
      logger.warn("accrueEarnings: completed record missing ids; skipping", {
        attendanceId,
      });
      return;
    }

    const db = getFirestore();
    const attendanceRef = db.collection(ATTENDANCE_COLLECTION).doc(attendanceId);
    const eventRef = db.collection(EVENTS_COLLECTION).doc(eventId);
    const earningsRef = db.collection(EARNINGS_COLLECTION).doc(studentId);

    await db.runTransaction(async (txn) => {
      // Re-read inside the transaction so the accrual decision is made against
      // the committed state, not the (possibly stale) trigger snapshot.
      const attendanceSnap = await txn.get(attendanceRef);
      if (!attendanceSnap.exists) {
        return;
      }

      const state = toAttendanceState(attendanceSnap.data());
      if (!shouldAccrue(state)) {
        // Already accrued, or no longer completed — exactly-once no-op.
        return;
      }

      const eventSnap = await txn.get(eventRef);
      const payPerHeadPaise = readPayPerHeadPaise(eventSnap.data());
      if (payPerHeadPaise === null) {
        logger.warn("accrueEarnings: event payPerHead unavailable; skipping", {
          attendanceId,
          eventId,
        });
        return;
      }

      // Earnings are persisted as decimal major units (rupees) to match the
      // client `MoneyMapper`; convert from the event's integer paise.
      const payPerHeadMajor = paiseToMajorUnits(payPerHeadPaise);

      // (a) Credit the student's earnings: bump the running total and the
      // per-event entry by payPerHead, creating the document on first accrual.
      txn.set(
        earningsRef,
        {
          studentId,
          total: FieldValue.increment(payPerHeadMajor),
          perEvent: { [eventId]: FieldValue.increment(payPerHeadMajor) },
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // (b) Flip the idempotency marker in the SAME transaction so the credit
      // and the marker commit atomically — guaranteeing exactly-once.
      txn.update(attendanceRef, { accrued: true });
    });

    logger.info("accrueEarnings: credited payPerHead", {
      attendanceId,
      eventId,
      studentId,
    });
  },
);
