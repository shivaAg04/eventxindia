/**
 * PURE notification-creation decision logic (backend-agnostic).
 *
 * Given an application creation or status change, this module decides exactly
 * which notification document to create and for whom — independent of Firebase
 * so it can be property-tested with `fast-check` (Property 26, task 28.4):
 *
 *   - creation              -> one `NewApplication` to the event's owning vendor (R13.4)
 *   - transition to Approved -> one `ApplicationApproved` to the applicant     (R13.1)
 *   - transition to Rejected -> one `ApplicationRejected` to the applicant     (R13.2)
 *
 * Exactly one notification (or none, for a non-triggering status change) is
 * produced per triggering event. The trigger wiring (`./triggers`) performs the
 * actual Firestore reads/writes on top of these decisions.
 */

/** Notification type discriminator (matches the `notifications` schema). */
export type NotificationType =
  | "ApplicationApproved"
  | "ApplicationRejected"
  | "EventReminder"
  | "NewApplication";

/** Lifecycle status of an application document. */
export type ApplicationStatus = "Pending" | "Approved" | "Rejected";

/** The payload embedded on a created notification document. */
export interface NotificationPayload {
  eventId?: string;
  applicationId?: string;
  title: string;
  body: string;
}

/** A notification the trigger layer should persist to `notifications/{id}`. */
export interface NotificationToCreate {
  type: NotificationType;
  recipientId: string;
  payload: NotificationPayload;
}

/** The application fields needed to decide notifications. */
export interface ApplicationFacts {
  applicationId: string;
  eventId: string;
  /** The applicant student. */
  studentId: string;
}

/**
 * Decide the single notification to create when an application is created.
 *
 * Always produces exactly one `NewApplication` addressed to the owning vendor
 * of the application's event (R13.4).
 */
export function notificationForCreatedApplication(
  application: ApplicationFacts,
  /** Owner of the event the student applied to. */
  vendorId: string,
): NotificationToCreate {
  return {
    type: "NewApplication",
    recipientId: vendorId,
    payload: {
      eventId: application.eventId,
      applicationId: application.applicationId,
      title: "New application",
      body: "A student applied to your event.",
    },
  };
}

/**
 * Decide the notification (if any) to create when an application's status
 * changes from `before` to `after`.
 *
 * Produces exactly one notification addressed to the applicant student when the
 * status transitions *into* Approved (R13.1) or Rejected (R13.2). Any other
 * change — including a no-op where the status is unchanged, or a transition
 * back to Pending — produces no notification.
 */
export function notificationForStatusChange(
  application: ApplicationFacts,
  before: ApplicationStatus,
  after: ApplicationStatus,
): NotificationToCreate | null {
  // Only a genuine transition into a terminal decision notifies the applicant.
  if (after === before) {
    return null;
  }
  if (after === "Approved") {
    return {
      type: "ApplicationApproved",
      recipientId: application.studentId,
      payload: {
        eventId: application.eventId,
        applicationId: application.applicationId,
        title: "Application approved",
        body: "Your application was approved.",
      },
    };
  }
  if (after === "Rejected") {
    return {
      type: "ApplicationRejected",
      recipientId: application.studentId,
      payload: {
        eventId: application.eventId,
        applicationId: application.applicationId,
        title: "Application rejected",
        body: "Your application was rejected.",
      },
    };
  }
  return null;
}
