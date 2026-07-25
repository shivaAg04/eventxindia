/// The state of a student's wallet withdrawal request.
///
/// A request is [pending] on creation and is moved to [approved] or [rejected]
/// by an admin. Any value outside this set is rejected at the boundary via
/// [WithdrawalStatusX.parse].
enum WithdrawalStatus {
  pending,
  approved,
  rejected;

  /// The canonical wire/storage representation, e.g. `"Pending"`.
  String get wireName {
    switch (this) {
      case WithdrawalStatus.pending:
        return 'Pending';
      case WithdrawalStatus.approved:
        return 'Approved';
      case WithdrawalStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Parsing helpers that enforce validity for [WithdrawalStatus] at the boundary.
extension WithdrawalStatusX on WithdrawalStatus {
  /// Parses a wire/storage string into a [WithdrawalStatus].
  ///
  /// Accepts exactly `Pending`, `Approved`, or `Rejected`; throws an
  /// [ArgumentError] for any unknown value.
  static WithdrawalStatus parse(String value) {
    for (final WithdrawalStatus status in WithdrawalStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown WithdrawalStatus');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static WithdrawalStatus? tryParse(String value) {
    for (final WithdrawalStatus status in WithdrawalStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }
}
