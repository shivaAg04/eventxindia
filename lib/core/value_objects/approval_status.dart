/// The approval status of a vendor.
///
/// A vendor defaults to [pending] on registration and may transition to
/// [approved] or [rejected] by an admin. Any value outside this set is rejected
/// at the boundary via [ApprovalStatusX.parse].
enum ApprovalStatus {
  pending,
  approved,
  rejected;

  /// The canonical wire/storage representation, e.g. `"Pending"`.
  String get wireName {
    switch (this) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Parsing helpers that enforce validity for [ApprovalStatus] at the boundary.
extension ApprovalStatusX on ApprovalStatus {
  /// Parses a wire/storage string into an [ApprovalStatus].
  ///
  /// Accepts exactly `Pending`, `Approved`, or `Rejected`. Throws an
  /// [ArgumentError] for any unknown value.
  static ApprovalStatus parse(String value) {
    for (final status in ApprovalStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown ApprovalStatus');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static ApprovalStatus? tryParse(String value) {
    for (final status in ApprovalStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }
}
