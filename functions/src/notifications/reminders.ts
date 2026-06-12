/**
 * PURE event-reminder selection logic (backend-agnostic).
 *
 * Given the events, the Approved applications, the reminders already sent, and
 * the current time, this module selects exactly the (student, event) pairs that
 * are due an `EventReminder`: events whose start time falls within the 24-hour
 * reminder window and for which a reminder has not already been sent to that
 * student (R13.3, Property 27). It is free of Firebase types so it can be
 * property-tested with `fast-check` (task 28.5).
 */

/** Length of the reminder window before an event's start, in milliseconds. */
export const REMINDER_WINDOW_MS = 24 * 60 * 60 * 1000;

/** The minimal event shape the selection needs. */
export interface ReminderEvent {
  eventId: string;
  /** Event start time as epoch milliseconds. */
  startTimeMs: number;
}

/** An Approved application linking a student to an event. */
export interface ApprovedApplication {
  eventId: string;
  studentId: string;
}

/** A (student, event) pair that should receive an `EventReminder`. */
export interface ReminderRecipient {
  studentId: string;
  eventId: string;
}

/** Stable key for a (student, event) reminder pair. */
export function reminderKey(studentId: string, eventId: string): string {
  return `${eventId}_${studentId}`;
}

/**
 * Select the (student, event) pairs due an event reminder at `nowMs`.
 *
 * A pair is selected iff all of the following hold:
 *   - the application is Approved for an event that exists, AND
 *   - the event's start time is in the future and at most 24h away
 *     (`nowMs <= startTimeMs <= nowMs + 24h`), AND
 *   - a reminder has not already been sent to that student for that event.
 *
 * `alreadySentKeys` holds `reminderKey(studentId, eventId)` for reminders that
 * have already been sent (or are in flight). The result contains no duplicates.
 */
export function selectReminderRecipients(input: {
  events: readonly ReminderEvent[];
  approvedApplications: readonly ApprovedApplication[];
  alreadySentKeys: ReadonlySet<string>;
  nowMs: number;
}): ReminderRecipient[] {
  const { events, approvedApplications, alreadySentKeys, nowMs } = input;

  // Index events whose start falls inside the reminder window for O(1) lookup.
  const windowStart = nowMs;
  const windowEnd = nowMs + REMINDER_WINDOW_MS;
  const dueEventStart = new Map<string, number>();
  for (const ev of events) {
    if (ev.startTimeMs >= windowStart && ev.startTimeMs <= windowEnd) {
      dueEventStart.set(ev.eventId, ev.startTimeMs);
    }
  }

  const selected: ReminderRecipient[] = [];
  const seen = new Set<string>();
  for (const app of approvedApplications) {
    if (!dueEventStart.has(app.eventId)) {
      continue;
    }
    const key = reminderKey(app.studentId, app.eventId);
    if (alreadySentKeys.has(key) || seen.has(key)) {
      continue;
    }
    seen.add(key);
    selected.push({ studentId: app.studentId, eventId: app.eventId });
  }
  return selected;
}
