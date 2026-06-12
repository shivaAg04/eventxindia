import '../../../../core/value_objects/money.dart';

/// Converts the decimal money amounts stored in Firestore to the pure domain
/// [Money] value object.
///
/// Earnings amounts are persisted as `decimal` major-unit values (e.g.
/// `123.45`) under the `earnings/{studentId}` document (design "Data Models").
/// Firestore surfaces those numbers as `num` (an `int` or `double`), so this
/// mapper normalises them into [Money], which stores the amount exactly as
/// integer minor units.
///
/// Earnings are *accumulated totals* rather than a single pay-per-head, so the
/// pay-per-head range constraint is relaxed: a value may legitimately be `0`
/// (no completed attendance) or exceed a single amount's upper bound.
class MoneyMapper {
  const MoneyMapper._();

  /// Maps a stored decimal [amount] (major units) to [Money].
  ///
  /// A `null` amount maps to [Money.zero], matching the empty-earnings state of
  /// a student with no completed attendance records (R11.5).
  static Money fromDecimal(num? amount) {
    if (amount == null) {
      return Money.zero;
    }
    return Money.fromMajorUnits(amount, requirePayPerHeadRange: false);
  }
}
