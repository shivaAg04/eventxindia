/// The delivery outcome of a [Notification] as it moves through the trusted
/// dispatch pipeline.
///
/// A notification starts [pending] on creation. The backend
/// `NotificationService` transitions it to:
/// - [delivered] once Firebase Cloud Messaging accepts it (R13.5),
/// - [skipped] when the recipient has no registered device token, with no
///   error raised (R13.7), or
/// - [failed] only after all retry attempts are exhausted, with the triggering
///   data preserved (R13.6, R13.8).
///
/// Any value outside this set is rejected at the boundary via
/// [DeliveryStatusX.parse].
enum DeliveryStatus {
  pending,
  delivered,
  skipped,
  failed;

  /// The canonical wire/storage representation, e.g. `"Pending"`.
  String get wireName {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.skipped:
        return 'Skipped';
      case DeliveryStatus.failed:
        return 'Failed';
    }
  }
}

/// Parsing helpers that enforce validity for [DeliveryStatus] at the boundary.
extension DeliveryStatusX on DeliveryStatus {
  /// Parses a wire/storage string into a [DeliveryStatus].
  ///
  /// Accepts exactly `Pending`, `Delivered`, `Skipped`, or `Failed`. Throws an
  /// [ArgumentError] for any unknown value.
  static DeliveryStatus parse(String value) {
    for (final status in DeliveryStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown DeliveryStatus');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static DeliveryStatus? tryParse(String value) {
    for (final status in DeliveryStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }
}
