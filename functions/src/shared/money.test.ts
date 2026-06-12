/**
 * Example tests establishing the unit + property-based testing pattern for the
 * trusted Cloud Functions package. Pure helpers are exercised directly — no
 * Firebase, no emulator, no network.
 */
import fc from 'fast-check';
import { applyCreditOnce, isValidPaise } from './money';

describe('isValidPaise', () => {
  it('accepts non-negative integers', () => {
    expect(isValidPaise(0)).toBe(true);
    expect(isValidPaise(15000)).toBe(true);
  });

  it('rejects negatives and non-integers', () => {
    expect(isValidPaise(-1)).toBe(false);
    expect(isValidPaise(10.5)).toBe(false);
  });
});

describe('applyCreditOnce', () => {
  it('credits once when not yet accrued', () => {
    expect(applyCreditOnce(1000, 250, false)).toBe(1250);
  });

  it('is a no-op when already accrued', () => {
    expect(applyCreditOnce(1000, 250, true)).toBe(1000);
  });

  // Property: applying a credit is idempotent. Crediting an already-accrued
  // record never changes the total, regardless of total and pay amounts.
  it('property: accrual is idempotent', () => {
    fc.assert(
      fc.property(
        fc.nat({ max: 1_000_000_000 }),
        fc.nat({ max: 1_000_000 }),
        (total, pay) => {
          const credited = applyCreditOnce(total, pay, false);
          // Re-applying with alreadyAccrued=true must not change the credited total.
          expect(applyCreditOnce(credited, pay, true)).toBe(credited);
        }
      ),
      { numRuns: 100 }
    );
  });
});
