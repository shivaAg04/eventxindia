/// A backend-neutral phone-number value object.
///
/// A [PhoneNumber] is always composed of an optional numeric country code and a
/// 10-digit national number. Validity is enforced at construction: invalid
/// input throws a [FormatException], so any successfully constructed instance is
/// guaranteed to be well-formed.
///
/// Two construction paths mirror the platform's two phone formats:
/// * [PhoneNumber.withCountryCode] — a country code plus a 10-digit national
///   number (the Student login format: country code + 10 national digits).
/// * [PhoneNumber.national] — exactly 10 national digits with no country code
///   (the Vendor login format).
///
/// Role-specific acceptance rules (which format a given flow requires) live in
/// the auth domain; this value object only guarantees structural validity.
class PhoneNumber {
  /// The optional country code (1–3 digits, no leading zero), without the `+`.
  ///
  /// `null` when the number was constructed as a bare national number.
  final String? countryCode;

  /// The 10-digit national number.
  final String nationalNumber;

  const PhoneNumber._(this.countryCode, this.nationalNumber);

  /// Creates a phone number from a [countryCode] and a 10-digit
  /// [nationalNumber].
  ///
  /// The [countryCode] may optionally start with `+`. It must be 1–3 digits
  /// with no leading zero. The [nationalNumber] must be exactly 10 digits.
  /// Throws a [FormatException] otherwise.
  factory PhoneNumber.withCountryCode({
    required String countryCode,
    required String nationalNumber,
  }) {
    final cc = countryCode.startsWith('+')
        ? countryCode.substring(1)
        : countryCode;
    if (!_countryCodePattern.hasMatch(cc)) {
      throw FormatException(
        'Invalid country code: must be 1-3 digits with no leading zero',
        countryCode,
      );
    }
    if (!_nationalPattern.hasMatch(nationalNumber)) {
      throw FormatException(
        'Invalid national number: must be exactly 10 digits',
        nationalNumber,
      );
    }
    return PhoneNumber._(cc, nationalNumber);
  }

  /// Creates a phone number from a bare 10-digit national number.
  ///
  /// Throws a [FormatException] if [nationalNumber] is not exactly 10 digits.
  factory PhoneNumber.national(String nationalNumber) {
    if (!_nationalPattern.hasMatch(nationalNumber)) {
      throw FormatException(
        'Invalid national number: must be exactly 10 digits',
        nationalNumber,
      );
    }
    return PhoneNumber._(null, nationalNumber);
  }

  /// Parses an E.164-style string such as `+919876543210` or a bare 10-digit
  /// national number such as `9876543210`.
  ///
  /// When the input starts with `+`, the remaining digits are split into a
  /// 1–3 digit country code followed by a 10-digit national number. Throws a
  /// [FormatException] for any input that does not match these shapes.
  factory PhoneNumber.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Phone number must not be empty');
    }
    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1);
      if (!_digitsOnly.hasMatch(digits) || digits.length <= 10) {
        throw FormatException('Invalid E.164 phone number', input);
      }
      final ccLength = digits.length - 10;
      if (ccLength < 1 || ccLength > 3) {
        throw FormatException('Invalid E.164 phone number', input);
      }
      return PhoneNumber.withCountryCode(
        countryCode: digits.substring(0, ccLength),
        nationalNumber: digits.substring(ccLength),
      );
    }
    return PhoneNumber.national(trimmed);
  }

  /// Whether this number carries a country code.
  bool get hasCountryCode => countryCode != null;

  /// The canonical E.164 representation, e.g. `+919876543210`.
  ///
  /// For a bare national number (no country code) this returns the 10 national
  /// digits without a leading `+`.
  String get e164 =>
      hasCountryCode ? '+$countryCode$nationalNumber' : nationalNumber;

  @override
  String toString() => e164;

  @override
  bool operator ==(Object other) =>
      other is PhoneNumber &&
      other.countryCode == countryCode &&
      other.nationalNumber == nationalNumber;

  @override
  int get hashCode => Object.hash(countryCode, nationalNumber);

  static final RegExp _countryCodePattern = RegExp(r'^[1-9]\d{0,2}$');
  static final RegExp _nationalPattern = RegExp(r'^\d{10}$');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');
}
