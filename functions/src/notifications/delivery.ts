/**
 * PURE notification-delivery decision logic (backend-agnostic).
 *
 * The trigger wiring (`./triggers`) performs the actual FCM dispatch and
 * Firestore writes; this module holds only the retry/skip/failure decision so
 * it can be property-tested with `fast-check` (Property 28, task 28.6) without
 * FCM or the emulator.
 *
 * Delivery semantics (R13.6–R13.8):
 *   - no device token            -> skip, no error, no retries (R13.7)
 *   - attempts already exhausted -> fail, preserving trigger data (R13.8)
 *   - last attempt < 60s ago     -> wait (retry no sooner than 60s apart, R13.6)
 *   - otherwise                  -> deliver (attempt now)
 */

/** Delivery lifecycle states for a notification document. */
export type DeliveryStatus = "Pending" | "Delivered" | "Skipped" | "Failed";

/** Maximum number of dispatch attempts before a notification is failed. */
export const MAX_ATTEMPTS = 3;

/** Minimum spacing between successive delivery attempts, in milliseconds. */
export const MIN_RETRY_INTERVAL_MS = 60 * 1000;

/**
 * The next action the delivery worker should take for a notification.
 *
 * - `skip`    -> recipient has no device token; record Skipped, never retry.
 * - `deliver` -> dispatch now (within the ≤3 attempt budget, ≥60s spacing).
 * - `wait`    -> the previous attempt was < 60s ago; defer to a later trigger.
 * - `fail`    -> all attempts exhausted; record Failed and preserve trigger data.
 */
export type DeliveryDecision = "skip" | "deliver" | "wait" | "fail";

/**
 * Decide what to do with a pending notification given its delivery state.
 *
 * @param input.hasDeviceToken whether the recipient has at least one FCM token.
 * @param input.attemptCount   number of dispatch attempts already made (0..3).
 * @param input.lastAttemptAtMs epoch ms of the last attempt, or null if none.
 * @param input.nowMs          current time as epoch ms.
 */
export function decideDelivery(input: {
  hasDeviceToken: boolean;
  attemptCount: number;
  lastAttemptAtMs: number | null;
  nowMs: number;
}): DeliveryDecision {
  // R13.7: nothing to dispatch to — skip without error and without retrying.
  if (!input.hasDeviceToken) {
    return "skip";
  }
  // R13.8: the 3-attempt budget is spent — record the terminal failure.
  if (input.attemptCount >= MAX_ATTEMPTS) {
    return "fail";
  }
  // R13.6: successive attempts must be at least 60 seconds apart. If a prior
  // attempt happened too recently, defer rather than attempting again now.
  if (
    input.lastAttemptAtMs !== null &&
    input.nowMs - input.lastAttemptAtMs < MIN_RETRY_INTERVAL_MS
  ) {
    return "wait";
  }
  return "deliver";
}
