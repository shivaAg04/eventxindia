/// The kind of push notification raised by a triggering domain event.
///
/// - [newApplication] notifies the owning vendor that a student applied to
///   their event (R13.4).
/// - [applicationApproved] / [applicationRejected] notify the applicant student
///   of a decision on their application (R13.1, R13.2).
/// - [eventReminder] reminds approved applicants 24 hours before an event
///   starts (R13.3).
///
/// Any value outside this set is rejected at the boundary via
/// [NotificationTypeX.parse].
enum NotificationType {
  newApplication,
  applicationApproved,
  applicationRejected,
  eventReminder;

  /// The canonical wire/storage representation, e.g. `"NewApplication"`.
  String get wireName {
    switch (this) {
      case NotificationType.newApplication:
        return 'NewApplication';
      case NotificationType.applicationApproved:
        return 'ApplicationApproved';
      case NotificationType.applicationRejected:
        return 'ApplicationRejected';
      case NotificationType.eventReminder:
        return 'EventReminder';
    }
  }
}

/// Parsing helpers that enforce validity for [NotificationType] at the
/// boundary.
extension NotificationTypeX on NotificationType {
  /// Parses a wire/storage string into a [NotificationType].
  ///
  /// Accepts exactly `NewApplication`, `ApplicationApproved`,
  /// `ApplicationRejected`, or `EventReminder`. Throws an [ArgumentError] for
  /// any unknown value.
  static NotificationType parse(String value) {
    for (final type in NotificationType.values) {
      if (type.wireName == value) {
        return type;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown NotificationType');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static NotificationType? tryParse(String value) {
    for (final type in NotificationType.values) {
      if (type.wireName == value) {
        return type;
      }
    }
    return null;
  }
}
