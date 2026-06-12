/**
 * Pure, backend-agnostic money helpers.
 *
 * Monetary values are represented as integer **paise** (1 rupee = 100 paise)
 * to keep arithmetic exact and avoid floating-point drift across any backend
 * (Cloud Functions today, a Node.js service later). These functions contain NO
 * Firebase types and NO side effects, so they are trivially unit- and
 * property-testable with `fast-check`.
 *
 * This module establishes the project pattern: trusted logic is written as PURE
 * functions here (and in the per-capability folders), separate from the Firebase
 * trigger wiring that lives in `index.ts` and is added in tasks 27-29.
 */

/** A monetary amount expressed as a whole number of paise. */
export type Paise = number;

/** Returns true when the value is a safe, non-negative integer amount of paise. */
export function isValidPaise(value: number): value is Paise {
  return Number.isInteger(value) && value >= 0 && Number.isSafeInteger(value);
}

/**
 * Adds a pay amount to a running total exactly once.
 *
 * Pure illustration of the "exactly-once accrual" shape used by the earnings
 * Cloud Function (task 27): given a current total and whether the credit has
 * already been applied, return the new total. Idempotent by construction — if
 * the credit was already applied, the total is unchanged.
 */
export function applyCreditOnce(
  currentTotalPaise: Paise,
  payPaise: Paise,
  alreadyAccrued: boolean
): Paise {
  if (alreadyAccrued) {
    return currentTotalPaise;
  }
  return currentTotalPaise + payPaise;
}
