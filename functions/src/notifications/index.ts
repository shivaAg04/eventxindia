/**
 * Notifications capability (NotificationService).
 *
 * Trusted notification creation and FCM dispatch with retry/skip/failure
 * semantics. The Firestore-triggered and scheduled Cloud Functions
 * (`onApplicationCreated`, `onApplicationStatusChange`, `eventReminders`,
 * `deliverNotification`) are wired in `./triggers`; their decision logic (which
 * notification to create, reminder selection, retry state machine) lives in the
 * pure `./creation`, `./reminders`, and `./delivery` modules so it can be
 * property-tested with `fast-check`.
 */
export * from "./creation";
export * from "./reminders";
export * from "./delivery";
