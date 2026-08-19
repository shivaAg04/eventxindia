/**
 * Cloud Functions entrypoint for the EventXIndia platform.
 *
 * This module is the ONLY place that wires the trusted backend capabilities
 * (earnings accrual, notifications, metrics) to Firebase triggers. All the
 * decision logic lives in PURE, backend-agnostic modules under `src/earnings`,
 * `src/notifications`, and `src/metrics` so it can be unit- and property-tested
 * with `fast-check` without the emulator or any network access.
 *
 * The actual triggered functions are added in later tasks (27-29); for now we
 * initialize the Firebase Admin app exactly once and expose placeholder export
 * seams that those tasks will fill in.
 */
import { initializeApp, getApps } from "firebase-admin/app";

// Initialize the Admin SDK a single time per cold start. Guard against double
// initialization, which throws under the Functions runtime.
if (getApps().length === 0) {
  initializeApp();
}

// --- Triggered function export seams (populated in tasks 27-29) -------------
// Earnings accrual (task 27): exported below.
// Notifications (task 28): export const onApplicationCreated = ...
//                          export const onApplicationStatusChange = ...
//                          export const eventReminders = ...
//                          export const deliverNotification = ...
// Metrics (task 29):       export const recomputeMetrics = ...

// Earnings accrual (task 27): the Firestore-triggered `accrueEarnings` function
// credits an event's payPerHead exactly once when an attendance record becomes
// completed, using the `accrued` idempotency marker inside a transaction
// (R11.1, R11.2). Re-exported here so the Functions runtime discovers it.
export { accrueEarnings } from "./earnings/accrueEarnings";

// Notifications (task 28): trusted notification creation + FCM dispatch behind
// the NotificationService capability. `onApplicationCreated` notifies the
// owning vendor (R13.4); `onApplicationStatusChange` notifies the applicant on
// Approved/Rejected (R13.1, R13.2); `eventReminders` sweeps for 24h-before
// reminders (R13.3); `deliverNotification` dispatches via FCM with skip / ≤3
// attempts ≥60s apart / Failed-after-exhaustion semantics (R13.5–R13.8).
export {
  onApplicationCreated,
  onApplicationStatusChange,
  eventReminders,
  deliverNotification,
} from "./notifications/triggers";

// Metrics (task 29): admin counter aggregator — Firestore-triggered recompute
// of `metrics/global` plus a scheduled fallback (R6.7).
export {
  recomputeMetricsOnStudentWrite,
  recomputeMetricsOnVendorWrite,
  recomputeMetricsOnEventWrite,
  recomputeMetricsScheduled,
} from "./metrics/triggers";

// Student track record: per-student counters (`studentStats/{studentId}`) —
// events approved for + attendance completed — recomputed on any application or
// attendance write. This is the trusted read surface a vendor uses to judge an
// applicant's history, since per-document rules stop them querying another
// vendor's applications/attendance themselves.
export {
  recomputeStudentStatsOnApplicationWrite,
  recomputeStudentStatsOnAttendanceWrite,
} from "./studentStats/triggers";
