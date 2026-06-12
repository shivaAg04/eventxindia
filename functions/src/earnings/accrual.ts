/**
 * PURE earnings-accrual logic (backend-agnostic).
 *
 * The trigger wiring (`./accrueEarnings`) reads/writes Firestore inside a
 * transaction; this module holds only the decision + reduction so it can be
 * property-tested with `fast-check` (task 27.2). Monetary values are
 * represented as integer paise to keep accrual exact and free of
 * floating-point drift (see design "Money" note; `payPerHead` is stored on the
 * event document in exact minor units).
 *
 * The reducer is idempotent on the `accrued` marker: applying a completed
 * attendance record whose earnings were already credited is a no-op. The
 * transactional re-check of that marker in the trigger turns this into an
 * exactly-once accrual across concurrent/duplicate writes (R11.1, R11.2).
 */

/** A student's accrued earnings, all amounts in integer paise. */
export interface Earnings {
  /** Sum of credited `payPerHead`, in paise. */
  totalPaise: number;
  /** Credited amount per completed event, in paise. */
  perEventPaise: Readonly<Record<string, number>>;
}

/** The minimal shape of a completed attendance record needed to accrue. */
export interface CompletedAttendance {
  eventId: string;
  /** Event pay-per-head, in integer paise. */
  payPerHeadPaise: number;
  /** Idempotency marker: true once earnings have already been credited. */
  accrued: boolean;
}

/**
 * The presence-only view of an `attendance/{id}` document that the accrual
 * decision needs.
 *
 * Only whether check-in/check-out happened (not their values) and the
 * `accrued` idempotency marker matter, so the times are modelled as booleans —
 * keeping this decision free of any Firebase `Timestamp` type and trivially
 * property-testable.
 */
export interface AttendanceState {
  /** True when the record has a check-in time. */
  hasCheckIn: boolean;
  /** True when the record has a check-out time. */
  hasCheckOut: boolean;
  /** The idempotency marker; true once earnings have already been credited. */
  accrued: boolean;
}

/** The zero/empty earnings value. */
export function emptyEarnings(): Earnings {
  return { totalPaise: 0, perEventPaise: {} };
}

/**
 * A record is "completed" once it has both a check-in and a check-out time.
 */
export function isCompleted(state: AttendanceState): boolean {
  return state.hasCheckIn && state.hasCheckOut;
}

/**
 * Decide whether this write should accrue earnings.
 *
 * Returns true exactly when the resulting (`after`) record is completed and has
 * not yet been accrued. A deleted document (`after === null`) never accrues.
 *
 * The decision intentionally depends only on the `after` state plus the
 * `accrued` marker rather than on a before→after transition: the marker is the
 * single source of idempotency truth, so re-evaluating it (here and again
 * inside the trigger's transaction) guarantees the pay is credited exactly once
 * even if the completing write and the accrual race or retry (R11.1, R11.2).
 */
export function shouldAccrue(after: AttendanceState | null): boolean {
  if (after === null) {
    return false;
  }
  return isCompleted(after) && after.accrued !== true;
}

/**
 * Credit a completed attendance record's pay to the given earnings.
 *
 * Returns the input unchanged when the record is already `accrued`, making the
 * reduction idempotent. Otherwise adds `payPerHeadPaise` to both the total and
 * the per-event entry. Always returns a new object (no mutation of the input).
 */
export function accrue(
  earnings: Earnings,
  record: CompletedAttendance,
): Earnings {
  if (record.accrued) {
    return earnings;
  }
  const prevForEvent = earnings.perEventPaise[record.eventId] ?? 0;
  return {
    totalPaise: earnings.totalPaise + record.payPerHeadPaise,
    perEventPaise: {
      ...earnings.perEventPaise,
      [record.eventId]: prevForEvent + record.payPerHeadPaise,
    },
  };
}
