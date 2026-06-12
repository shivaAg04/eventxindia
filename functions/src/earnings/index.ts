/**
 * Earnings capability (EarningsService).
 *
 * Trusted exactly-once earnings accrual. The Firestore-triggered Cloud Function
 * `accrueEarnings` (see `./accrueEarnings`) credits the owning event's
 * `payPerHead` exactly once when an attendance record becomes completed, using
 * the `accrued` idempotency marker inside a transaction (R11.1, R11.2). The
 * idempotent accrual decision/reduction lives as pure functions (`./accrual`)
 * so it can be property-tested with `fast-check` independently of any Firebase
 * trigger (task 27.2).
 */
export { accrueEarnings } from "./accrueEarnings";
export * from "./accrual";
