import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../entities/user_role.dart';

/// Pure, role-aware phone-format validator for the authentication flows
/// (R1.5, R2.2).
///
/// The two login paths accept different phone shapes:
///
/// * **Vendor** ([UserRole.vendor]) — exactly 10 numeric digits with **no**
///   country code. Anything else (empty, non-digits, wrong length, or a
///   leading country code) is rejected (R2.2).
/// * **Student / Admin** ([UserRole.student], [UserRole.admin]) — a country
///   code followed by a 10-digit national number, e.g. `+919876543210`. A bare
///   national number (missing country code) or any malformed input is rejected
///   (R1.5).
///
/// On success the validator returns the well-formed [PhoneNumber] value object
/// so the caller can hand it straight to the repository; on failure it returns
/// a [ValidationFailure] carrying a `phone` [FieldError]. It performs no I/O and
/// has no dependencies, so it is directly example/property-testable
/// (Property 3).
class PhoneValidator {
  const PhoneValidator();

  /// The form-field name reported in returned [FieldError]s.
  static const String fieldName = 'phone';

  /// India's country code; every login number is normalised to it.
  static const String indiaCountryCode = '91';

  /// Validates [rawPhone] for [role].
  ///
  /// The app is India-only: every role logs in with exactly 10 digits, which
  /// are normalised to the `+91` E.164 form. Anything other than 10 digits is
  /// rejected. Returns the parsed [PhoneNumber] on success or a
  /// [ValidationFailure] identifying the `phone` field on failure. [role] is
  /// retained for API compatibility but no longer changes the accepted format.
  Result<PhoneNumber, Failure> call(String rawPhone, UserRole role) {
    final String trimmed = rawPhone.trim();
    if (trimmed.isEmpty) {
      return _invalid('Phone number is required.');
    }
    if (!_nationalOnly.hasMatch(trimmed)) {
      return _invalid('Enter a valid 10-digit mobile number.');
    }
    return Result<PhoneNumber, Failure>.ok(
      PhoneNumber.withCountryCode(
        countryCode: indiaCountryCode,
        nationalNumber: trimmed,
      ),
    );
  }

  Result<PhoneNumber, Failure> _invalid(String message) {
    return Result<PhoneNumber, Failure>.err(
      ValidationFailure(
        message: message,
        fieldErrors: <FieldError>[
          FieldError(field: fieldName, message: message),
        ],
      ),
    );
  }

  static final RegExp _nationalOnly = RegExp(r'^\d{10}$');
}
