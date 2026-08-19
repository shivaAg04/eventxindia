/**
 * Student track-record capability (StudentStatsService).
 *
 * Trusted per-student counter aggregation written to `studentStats/{studentId}`:
 * how many events the student was approved for, and how many they completed
 * attendance for. A vendor reviewing an applicant reads this one document —
 * they cannot derive it themselves, since attendance/application reads are
 * scoped to their own events.
 *
 * The counting logic is written as pure functions in `counting.ts` so it can be
 * property-tested with `fast-check`; the Firestore trigger wiring lives in
 * `triggers.ts`.
 */
export * from "./counting";
export {
  recomputeStudentStatsOnApplicationWrite,
  recomputeStudentStatsOnAttendanceWrite,
} from "./triggers";
