/// The review status of a student's application to an event.
///
/// An application is [pending] on creation and may transition to [approved] or
/// [rejected]. Any value outside this set is rejected at the boundary via
/// [ApplicationStatusX.parse].
enum ApplicationStatus {
  pending,
  approved,
  rejected;

  /// The canonical wire/storage representation, e.g. `"Pending"`.
  String get wireName {
    switch (this) {
      case ApplicationStatus.pending:
        return 'Pending';
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Parsing helpers that enforce validity for [ApplicationStatus] at the
/// boundary.
extension ApplicationStatusX on ApplicationStatus {
  /// Parses a wire/storage string into an [ApplicationStatus].
  ///
  /// Accepts exactly `Pending`, `Approved`, or `Rejected`. Throws an
  /// [ArgumentError] for any unknown value.
  static ApplicationStatus parse(String value) {
    for (final status in ApplicationStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown ApplicationStatus');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static ApplicationStatus? tryParse(String value) {
    for (final status in ApplicationStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }
}
