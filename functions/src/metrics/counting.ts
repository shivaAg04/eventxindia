/**
 * PURE admin-metrics counting logic (backend-agnostic).
 *
 * Mirrors the Dart `countMetrics` (lib/features/admin/domain/count_metrics.dart)
 * so the client and trusted aggregator agree on what the four admin counters
 * mean. This module holds NO Firebase types and NO side effects, so it can be
 * unit- and property-tested with `fast-check` without the emulator.
 *
 * The trigger wiring (`triggers.ts`) reads collection counts/statuses from
 * Firestore and feeds them here to produce the value written to `metrics/global`.
 */

/** Canonical event status wire strings (see EventStatus.wireName in Dart). */
export const ACTIVE_STATUS = "Active";
export const CLOSED_STATUS = "Closed";
export const COMPLETED_STATUS = "Completed";

/** The admin dashboard counters written to `metrics/global` (R6.7). */
export interface Metrics {
  /** Number of registered students. >= 0 */
  totalStudents: number;
  /** Number of registered vendors. >= 0 */
  totalVendors: number;
  /** Number of events with status "Active". >= 0 */
  activeEvents: number;
  /** Number of events with status "Completed". >= 0 */
  completedEvents: number;
}

/**
 * Counts the number of events whose status is exactly "Active".
 *
 * Pure helper used both directly (when full event lists are available) and to
 * reason about aggregation results.
 */
export function countActiveEvents(statuses: readonly string[]): number {
  return statuses.filter((status) => status === ACTIVE_STATUS).length;
}

/** Counts the number of events whose status is exactly "Completed". */
export function countCompletedEvents(statuses: readonly string[]): number {
  return statuses.filter((status) => status === COMPLETED_STATUS).length;
}

/**
 * Computes the admin [Metrics] from raw collection contents.
 *
 * - `totalStudents` = number of students.
 * - `totalVendors` = number of vendors.
 * - `activeEvents` = number of events with status "Active".
 * - `completedEvents` = number of events with status "Completed".
 *
 * Every count is a non-negative integer by construction (R6.7). Mirrors the
 * Dart `countMetrics`.
 */
export function countMetrics(input: {
  studentCount: number;
  vendorCount: number;
  eventStatuses: readonly string[];
}): Metrics {
  return {
    totalStudents: input.studentCount,
    totalVendors: input.vendorCount,
    activeEvents: countActiveEvents(input.eventStatuses),
    completedEvents: countCompletedEvents(input.eventStatuses),
  };
}

/**
 * Builds [Metrics] directly from precomputed counts.
 *
 * Used by the trigger wiring when `count()` aggregation queries supply the
 * active/completed tallies server-side (avoiding reading every event document).
 * Negative inputs are clamped to 0 so the non-negativity invariant holds even
 * if an upstream count is malformed.
 */
export function metricsFromCounts(input: {
  totalStudents: number;
  totalVendors: number;
  activeEvents: number;
  completedEvents: number;
}): Metrics {
  const nonNegInt = (value: number): number =>
    Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
  return {
    totalStudents: nonNegInt(input.totalStudents),
    totalVendors: nonNegInt(input.totalVendors),
    activeEvents: nonNegInt(input.activeEvents),
    completedEvents: nonNegInt(input.completedEvents),
  };
}
