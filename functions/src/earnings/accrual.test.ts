/**
 * Toolchain-proving tests for the pure earnings reducer.
 *
 * These exercise jest + ts-jest + fast-check end-to-end so later tasks (27)
 * can build on a verified toolchain. The exactly-once property required by the
 * spec (Property 23) is implemented in task 27.2.
 */
import fc from "fast-check";
import { accrue, emptyEarnings, Earnings } from "./accrual";

describe("accrue (pure earnings reducer)", () => {
  it("credits pay-per-head to total and per-event on a fresh record", () => {
    const result = accrue(emptyEarnings(), {
      eventId: "e1",
      payPerHeadPaise: 50000,
      accrued: false,
    });
    expect(result.totalPaise).toBe(50000);
    expect(result.perEventPaise.e1).toBe(50000);
  });

  it("is a no-op when the record is already accrued", () => {
    const start: Earnings = { totalPaise: 50000, perEventPaise: { e1: 50000 } };
    const result = accrue(start, {
      eventId: "e1",
      payPerHeadPaise: 50000,
      accrued: true,
    });
    expect(result).toEqual(start);
  });

  it("does not mutate the input earnings", () => {
    const start = emptyEarnings();
    accrue(start, { eventId: "e1", payPerHeadPaise: 100, accrued: false });
    expect(start).toEqual({ totalPaise: 0, perEventPaise: {} });
  });

  // Property: applying an already-accrued record never changes earnings.
  it("[property] re-applying an accrued record is idempotent", () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 0, max: 1_000_000 }),
        fc.string({ minLength: 1 }),
        fc.integer({ min: 1, max: 999_999_999 }),
        (total, eventId, pay) => {
          const earnings: Earnings = {
            totalPaise: total,
            perEventPaise: { [eventId]: total },
          };
          const result = accrue(earnings, {
            eventId,
            payPerHeadPaise: pay,
            accrued: true,
          });
          expect(result).toEqual(earnings);
        },
      ),
      { numRuns: 100 },
    );
  });
});
