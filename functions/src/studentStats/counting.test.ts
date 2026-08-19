/**
 * Tests for the pure student track-record counting logic.
 *
 * Unit tests pin down the two counters and their edge cases; the property tests
 * assert the invariants a vendor's hiring decision relies on: each counter is
 * the cardinality of the matching subset, both are non-negative integers, and
 * `attendanceCompleted` never exceeds `eventsParticipated` for a consistent
 * data set (a student can only work an event they were approved for).
 */
import fc from "fast-check";
import type { AttendanceState } from "../earnings/accrual";
import {
  APPROVED_STATUS,
  countApprovedApplications,
  countCompletedAttendance,
  countStudentStats,
  studentStatsFromCounts,
} from "./counting";

const state = (hasCheckIn: boolean, hasCheckOut: boolean): AttendanceState => ({
  hasCheckIn,
  hasCheckOut,
  accrued: false,
});

describe("countApprovedApplications", () => {
  it("counts only Approved applications", () => {
    expect(
      countApprovedApplications([
        APPROVED_STATUS,
        "Pending",
        APPROVED_STATUS,
        "Rejected",
      ]),
    ).toBe(2);
  });

  it("is zero for an empty list", () => {
    expect(countApprovedApplications([])).toBe(0);
  });

  it("does not count a differently-cased status", () => {
    expect(countApprovedApplications(["approved", "APPROVED"])).toBe(0);
  });
});

describe("countCompletedAttendance", () => {
  it("counts only records with both a check-in and a check-out", () => {
    expect(
      countCompletedAttendance([
        state(true, true),
        state(true, false), // checked in, still working
        state(false, false), // no-show
        state(true, true),
      ]),
    ).toBe(2);
  });

  it("does not count a check-out without a check-in", () => {
    expect(countCompletedAttendance([state(false, true)])).toBe(0);
  });

  it("is zero for an empty list", () => {
    expect(countCompletedAttendance([])).toBe(0);
  });
});

describe("countStudentStats", () => {
  it("combines both counters for one student", () => {
    expect(
      countStudentStats({
        studentId: "s1",
        applicationStatuses: [APPROVED_STATUS, APPROVED_STATUS, "Pending"],
        attendanceStates: [state(true, true), state(true, false)],
      }),
    ).toEqual({
      studentId: "s1",
      eventsParticipated: 2,
      attendanceCompleted: 1,
    });
  });

  it("is all-zero for a student with no history", () => {
    expect(
      countStudentStats({
        studentId: "s1",
        applicationStatuses: [],
        attendanceStates: [],
      }),
    ).toEqual({
      studentId: "s1",
      eventsParticipated: 0,
      attendanceCompleted: 0,
    });
  });
});

describe("studentStatsFromCounts", () => {
  it("clamps negative counts to zero", () => {
    expect(
      studentStatsFromCounts({
        studentId: "s1",
        eventsParticipated: -3,
        attendanceCompleted: -1,
      }),
    ).toEqual({
      studentId: "s1",
      eventsParticipated: 0,
      attendanceCompleted: 0,
    });
  });

  it("truncates fractional counts and zeroes non-finite ones", () => {
    expect(
      studentStatsFromCounts({
        studentId: "s1",
        eventsParticipated: 4.9,
        attendanceCompleted: Number.NaN,
      }),
    ).toEqual({
      studentId: "s1",
      eventsParticipated: 4,
      attendanceCompleted: 0,
    });
  });
});

describe("student-stats counting properties", () => {
  it("each counter equals the cardinality of its matching subset", () => {
    fc.assert(
      fc.property(
        fc.array(fc.constantFrom(APPROVED_STATUS, "Pending", "Rejected")),
        fc.array(
          fc.record({
            hasCheckIn: fc.boolean(),
            hasCheckOut: fc.boolean(),
            accrued: fc.boolean(),
          }),
        ),
        (statuses, states) => {
          const stats = countStudentStats({
            studentId: "s1",
            applicationStatuses: statuses,
            attendanceStates: states,
          });
          expect(stats.eventsParticipated).toBe(
            statuses.filter((s) => s === APPROVED_STATUS).length,
          );
          expect(stats.attendanceCompleted).toBe(
            states.filter((s) => s.hasCheckIn && s.hasCheckOut).length,
          );
        },
      ),
      { numRuns: 200 },
    );
  });

  it("both counters are non-negative integers for any input", () => {
    fc.assert(
      fc.property(
        fc.double({ noDefaultInfinity: false, noNaN: false }),
        fc.double({ noDefaultInfinity: false, noNaN: false }),
        (participated, completed) => {
          const stats = studentStatsFromCounts({
            studentId: "s1",
            eventsParticipated: participated,
            attendanceCompleted: completed,
          });
          expect(Number.isInteger(stats.eventsParticipated)).toBe(true);
          expect(Number.isInteger(stats.attendanceCompleted)).toBe(true);
          expect(stats.eventsParticipated).toBeGreaterThanOrEqual(0);
          expect(stats.attendanceCompleted).toBeGreaterThanOrEqual(0);
        },
      ),
      { numRuns: 200 },
    );
  });

  it("completed attendance never exceeds approved events when every worked event was approved", () => {
    fc.assert(
      fc.property(
        fc.array(fc.boolean(), { minLength: 0, maxLength: 30 }),
        (workedFlags) => {
          // One approved application per attendance record — the real-world
          // invariant, since attendance only exists for an approved applicant.
          const stats = countStudentStats({
            studentId: "s1",
            applicationStatuses: workedFlags.map(() => APPROVED_STATUS),
            attendanceStates: workedFlags.map((worked) =>
              state(true, worked),
            ),
          });
          expect(stats.attendanceCompleted).toBeLessThanOrEqual(
            stats.eventsParticipated,
          );
        },
      ),
      { numRuns: 200 },
    );
  });
});
