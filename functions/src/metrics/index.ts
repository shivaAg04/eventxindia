/**
 * Metrics capability (MetricsService).
 *
 * Trusted admin counter aggregation written to `metrics/global`. The
 * Firestore-triggered + scheduled Cloud Function `recomputeMetrics` is wired in
 * task 29; the counting logic is written as pure functions so it can be
 * property-tested with `fast-check`.
 *
 * Trigger exports (task 29) are wired in `triggers.ts`; the pure counting logic
 * lives in `counting.ts` so it can be property-tested with `fast-check`.
 */
export * from "./counting";
export {
  recomputeMetricsOnStudentWrite,
  recomputeMetricsOnVendorWrite,
  recomputeMetricsOnEventWrite,
  recomputeMetricsScheduled,
} from "./triggers";
