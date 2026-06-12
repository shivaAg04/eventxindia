/**
 * Tests for the pure admin-metrics counting logic.
 *
 * Unit tests pin down the four counters and edge cases; the property test
 * mirrors the design's metrics-counting property: for any collections, each
 * counter equals the cardinality of the matching subset and is a non-negative
 * integer (Validates: Requirements 6.7).
 */
import fc from "fast-check";
import {
  ACTIVE_STATUS,
  CLOSED_STATUS,
  COMPLETED_STATUS,
  countMetrics,
  metricsFromCounts,
} from "./counting";

describe("countMetrics (pure admin counters)", () => {
  it("counts students, vendors, active and completed events", () => {
    const metrics = countMetrics({
      studentCount: 5,
      vendorCount: 2,
      eventStatuses: [
        ACTIVE_STATUS,
        ACTIVE_STATUS,
        COMPLETED_STATUS,
        CLOSED_STATUS,
      ],
    });
    expect(metrics).toEqual({
      totalStudents: 5,
      totalVendors: 2,
      activeEvents: 2,
      completedEvents: 1,
    });
  });

  it("returns all-zero counters for empty collections", () => {
    expect(
      countMetrics({ studentCount: 0, vendorCount: 0, eventStatuses: [] }),
    ).toEqual({
      totalStudents: 0,
      totalVendors: 0,
      activeEvents: 0,
      completedEvents: 0,
    });
  });

  it("ignores Closed events in both event counters", () => {
    const metrics = countMetrics({
      studentCount: 0,
      vendorCount: 0,
      eventStatuses: [CLOSED_STATUS, CLOSED_STATUS],
    });
    expect(metrics.activeEvents).toBe(0);
    expect(metrics.completedEvents).toBe(0);
  });
});

describe("metricsFromCounts", () => {
  it("passes through valid non-negative integer counts", () => {
    expect(
      metricsFromCounts({
        totalStudents: 3,
        totalVendors: 1,
        activeEvents: 4,
        completedEvents: 2,
      }),
    ).toEqual({
      totalStudents: 3,
      totalVendors: 1,
      activeEvents: 4,
      completedEvents: 2,
    });
  });

  it("clamps malformed (negative/non-finite) counts to non-negative ints", () => {
    expect(
      metricsFromCounts({
        totalStudents: -1,
        totalVendors: Number.NaN,
        activeEvents: 2.9,
        completedEvents: Infinity,
      }),
    ).toEqual({
      totalStudents: 0,
      totalVendors: 0,
      activeEvents: 2,
      completedEvents: 0,
    });
  });
});

// Property: metrics equal the cardinalities of the matching subsets, and every
// count is an integer >= 0. **Validates: Requirements 6.7**
describe("[property] admin metrics counting", () => {
  const statusArb = fc.constantFrom(
    ACTIVE_STATUS,
    CLOSED_STATUS,
    COMPLETED_STATUS,
  );

  it("each counter equals its subset cardinality and is a non-negative int", () => {
    fc.assert(
      fc.property(
        fc.nat({ max: 10_000 }),
        fc.nat({ max: 10_000 }),
        fc.array(statusArb, { maxLength: 500 }),
        (studentCount, vendorCount, eventStatuses) => {
          const metrics = countMetrics({
            studentCount,
            vendorCount,
            eventStatuses,
          });

          const expectedActive = eventStatuses.filter(
            (s) => s === ACTIVE_STATUS,
          ).length;
          const expectedCompleted = eventStatuses.filter(
            (s) => s === COMPLETED_STATUS,
          ).length;

          expect(metrics.totalStudents).toBe(studentCount);
          expect(metrics.totalVendors).toBe(vendorCount);
          expect(metrics.activeEvents).toBe(expectedActive);
          expect(metrics.completedEvents).toBe(expectedCompleted);

          for (const count of Object.values(metrics)) {
            expect(Number.isInteger(count)).toBe(true);
            expect(count).toBeGreaterThanOrEqual(0);
          }
        },
      ),
      { numRuns: 100 },
    );
  });
});
