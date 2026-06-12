/// A fixed-precision (two decimal place) monetary value object.
///
/// [Money] is used for currency amounts such as an event's pay-per-head and a
/// student's estimated earnings. To avoid binary floating-point rounding error,
/// the amount is stored internally as an integer number of **minor units**
/// (1/100 of a major unit, e.g. paise). Arithmetic is therefore exact.
///
/// Validity is enforced at construction. The platform constrains a single
/// pay-per-head amount to the range `0.01 .. 9999999.99`; use
/// [Money.fromMajorUnits] / [Money.fromMinorUnits] for that constraint, and
/// [Money.zero] / accumulating arithmetic for running totals (e.g. earnings),
/// which may legitimately be `0` or exceed a single amount's upper bound.
class Money implements Comparable<Money> {
  /// The amount expressed in minor units (1/100 of a major unit).
  ///
  /// Always non-negative. `12345` represents `123.45`.
  final int minorUnits;

  const Money._(this.minorUnits);

  /// The largest amount a single pay-per-head value may take: `9999999.99`.
  static const int maxPayPerHeadMinorUnits = 999999999;

  /// The smallest amount a single pay-per-head value may take: `0.01`.
  static const int minPayPerHeadMinorUnits = 1;

  /// A zero amount. Valid as an accumulator starting point (e.g. earnings).
  static const Money zero = Money._(0);

  /// Creates a [Money] from an integer count of [minorUnits].
  ///
  /// Throws an [ArgumentError] if [minorUnits] is negative or outside the
  /// pay-per-head range `1 .. 999999999` when [requirePayPerHeadRange] is true
  /// (the default). Pass `requirePayPerHeadRange: false` to allow `0` and
  /// larger accumulated totals.
  factory Money.fromMinorUnits(
    int minorUnits, {
    bool requirePayPerHeadRange = true,
  }) {
    if (minorUnits < 0) {
      throw ArgumentError.value(
        minorUnits,
        'minorUnits',
        'Money cannot be negative',
      );
    }
    if (requirePayPerHeadRange &&
        (minorUnits < minPayPerHeadMinorUnits ||
            minorUnits > maxPayPerHeadMinorUnits)) {
      throw ArgumentError.value(
        minorUnits,
        'minorUnits',
        'Amount must be within 0.01 .. 9999999.99',
      );
    }
    return Money._(minorUnits);
  }

  /// Creates a [Money] from a major-unit amount such as `123.45`.
  ///
  /// The amount is rounded to the nearest minor unit (two decimal places) only
  /// when the third decimal is within floating-point tolerance of an exact
  /// half; otherwise non-representable inputs (more than two meaningful decimal
  /// places) throw an [ArgumentError] to avoid silent precision loss.
  /// Validation against the pay-per-head range follows [Money.fromMinorUnits].
  factory Money.fromMajorUnits(
    num amount, {
    bool requirePayPerHeadRange = true,
  }) {
    final scaled = amount * 100;
    final rounded = scaled.round();
    if ((scaled - rounded).abs() > _epsilon) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount has more than two decimal places',
      );
    }
    return Money.fromMinorUnits(
      rounded,
      requirePayPerHeadRange: requirePayPerHeadRange,
    );
  }

  /// Parses a decimal string such as `"123.45"`, `"0.01"`, or `"42"`.
  ///
  /// Accepts at most two fractional digits. Throws a [FormatException] for
  /// malformed input and an [ArgumentError] for out-of-range values.
  factory Money.parse(String input, {bool requirePayPerHeadRange = true}) {
    final trimmed = input.trim();
    if (!_decimalPattern.hasMatch(trimmed)) {
      throw FormatException('Invalid money format', input);
    }
    final parts = trimmed.split('.');
    final whole = int.parse(parts[0]);
    var fraction = 0;
    if (parts.length == 2) {
      final frac = parts[1].padRight(2, '0');
      fraction = int.parse(frac);
    }
    return Money.fromMinorUnits(
      whole * 100 + fraction,
      requirePayPerHeadRange: requirePayPerHeadRange,
    );
  }

  /// The amount expressed in major units as a `double`, e.g. `123.45`.
  ///
  /// Provided for display/formatting; the authoritative value is [minorUnits].
  double get amount => minorUnits / 100;

  /// Returns the sum of this amount and [other].
  ///
  /// The result may exceed the single pay-per-head upper bound (totals
  /// accumulate), so range checking is relaxed; the result is still
  /// non-negative.
  Money operator +(Money other) =>
      Money.fromMinorUnits(minorUnits + other.minorUnits,
          requirePayPerHeadRange: false);

  /// Returns the difference of this amount and [other].
  ///
  /// Throws an [ArgumentError] if the result would be negative.
  Money operator -(Money other) =>
      Money.fromMinorUnits(minorUnits - other.minorUnits,
          requirePayPerHeadRange: false);

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  /// A canonical two-decimal string, e.g. `"123.45"`.
  String get formatted {
    final major = minorUnits ~/ 100;
    final minor = minorUnits % 100;
    return '$major.${minor.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => formatted;

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  static const double _epsilon = 1e-6;
  static final RegExp _decimalPattern = RegExp(r'^\d+(\.\d{1,2})?$');
}
