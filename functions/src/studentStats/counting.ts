/**
 * PURE student track-record counting logic (backend-agnostic).
 *
 * Mirrors the Dart `StudentStats` entity
 * (lib/features/profile/domain/entities/student_stats.dart) so the client and
 * the trusted aggregator agree on what a student's two headline counters mean:
 *
 *   - `eventsParticipated`  — how many events the student was approved for.
 *   - `attendanceCompleted` — how many of those they actually worked, i.e.
 *     attendance records carrying BOTH a check-in and a check-out.
 *
 * "Completed" is deliberately the same predicate the earnings accrual uses
 * (`isCompleted` in ../earnings/accrual.ts), so a student's attendance count can
 * never disagree with what they were paid for.
 *
 * This module holds NO Firebase types and NO side effects, so it can be unit-
 * and property-tested with `fast-check` without the emulator.
 */
import { isCompleted, type AttendanceState } from "../earnings/accrual";

/** Canonical application status wire string (see ApplicationStatus in Dart). */
export const APPROVED_STATUS = "Approved";

/** A single student's aggregated track record, written to `studentStats/{uid}`. */
export interface StudentStats {
  /** The student the counters belong to. */
  studentId: string;
  /** Events the student was approved for. >= 0 */
  eventsParticipated: number;
  /** Events the student both checked in and out of. >= 0 */
  attendanceCompleted: number;
}

/**
 * Counts how many of [states] are completed attendance records.
 *
 * Delegates the per-record decision to the earnings `isCompleted` predicate so
 * the two capabilities cannot drift apart.
 */
export function countCompletedAttendance(
  states: readonly AttendanceState[],
): number {
  return states.filter(isCompleted).length;
}

/**
 * Counts the applications whose status is exactly "Approved".
 *
 * An approved application is what "participated in an event" means: the vendor
 * selected the student for that event.
 */
export function countApprovedApplications(
  statuses: readonly string[],
): number {
  return statuses.filter((status) => status === APPROVED_STATUS).length;
}

/**
 * Builds [StudentStats] from precomputed counts.
 *
 * Negative, fractional, or non-finite inputs are clamped to a non-negative
 * integer so the counters can never represent an impossible track record even
 * if an upstream count is malformed — the same invariant the Dart entity
 * enforces at construction.
 */
export function studentStatsFromCounts(input: {
  studentId: string;
  eventsParticipated: number;
  attendanceCompleted: number;
}): StudentStats {
  return {
    studentId: input.studentId,
    eventsParticipated: nonNegInt(input.eventsParticipated),
    attendanceCompleted: nonNegInt(input.attendanceCompleted),
  };
}

/**
 * Computes a student's stats from raw collection contents.
 *
 * The counterpart of [studentStatsFromCounts] for when full lists are
 * available rather than server-side aggregates.
 */
export function countStudentStats(input: {
  studentId: string;
  applicationStatuses: readonly string[];
  attendanceStates: readonly AttendanceState[];
}): StudentStats {
  return studentStatsFromCounts({
    studentId: input.studentId,
    eventsParticipated: countApprovedApplications(input.applicationStatuses),
    attendanceCompleted: countCompletedAttendance(input.attendanceStates),
  });
}

function nonNegInt(value: number): number {
  return Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}
