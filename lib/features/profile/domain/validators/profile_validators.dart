import '../../../../core/error/failure.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../entities/student.dart';
import '../repositories/storage_repository.dart';

/// The raw, pre-persistence input for registering a [Student] profile.
///
/// This is a pure domain value used by [validateStudentProfile] and the
/// `RegisterStudent` use case. Fields that the user may have left unset are
/// nullable so the validator can report them as missing (R1.6, R1.7). The
/// [phone] is a [PhoneNumber] value object, so its structural validity is
/// already guaranteed by construction.
class StudentProfileInput {
  const StudentProfileInput({
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.city,
    required this.heightCm,
    required this.photo,
  });

  /// The student's full name (required, 1..100 characters).
  final String fullName;

  /// The student's phone number (structurally validated by [PhoneNumber]).
  final PhoneNumber phone;

  /// The student's gender; `null` when not yet selected.
  final Gender? gender;

  /// The student's date of birth; `null` when not yet provided. Must be a date
  /// strictly in the past.
  final DateTime? dateOfBirth;

  /// The student's city (required, 1..100 characters).
  final String city;

  /// The student's height in centimetres; `null` when not yet provided. Must
  /// be within 50..250.
  final int? heightCm;

  /// The profile photo to upload; `null` when none was chosen.
  final PhotoUpload? photo;
}

/// The raw, pre-persistence input for registering a [Vendor] profile.
///
/// This is a pure domain value used by [validateVendorProfile] and the
/// `RegisterVendor` use case. The [phone] is a [PhoneNumber] value object whose
/// 10-digit national format is guaranteed by construction (R2.6). The optional
/// [aadhaarOrPan], [website], and [socialLinks] are stored only when provided
/// (R2.7).
class VendorProfileInput {
  const VendorProfileInput({
    required this.fullName,
    required this.agencyName,
    required this.phone,
    required this.city,
    required this.address,
    this.aadhaarOrPan,
    this.website,
    this.socialLinks = const <String>[],
  });

  /// The vendor's full name (required, 1..100 characters).
  final String fullName;

  /// The vendor's agency name (required, 1..150 characters).
  final String agencyName;

  /// The vendor's phone number (structurally validated by [PhoneNumber]).
  final PhoneNumber phone;

  /// The vendor's city (required, 1..100 characters).
  final String city;

  /// The vendor's address (required, 1..250 characters).
  final String address;

  /// The vendor's optional Aadhaar/PAN identifier (R2.7).
  final String? aadhaarOrPan;

  /// The vendor's optional website (R2.7).
  final String? website;

  /// The vendor's optional social links; empty when none provided (R2.7).
  final List<String> socialLinks;
}

/// The canonical field names used in [FieldError]s so the presentation layer
/// can map each error back to the form field that produced it.
abstract final class ProfileFields {
  static const String fullName = 'fullName';
  static const String gender = 'gender';
  static const String dateOfBirth = 'dateOfBirth';
  static const String city = 'city';
  static const String heightCm = 'heightCm';
  static const String profilePhoto = 'profilePhoto';
  static const String agencyName = 'agencyName';
  static const String address = 'address';
}

/// The maximum accepted profile-photo size in bytes (5 MB) (R1.8, R1.9).
const int maxPhotoSizeBytes = 5 * 1024 * 1024;

/// The set of accepted profile-photo MIME content types (R1.8).
const Set<String> acceptedPhotoContentTypes = <String>{
  'image/jpeg',
  'image/png',
};

/// Validates a [Student] registration [input] against the required-field rules
/// of R1.6/R1.7, returning the exact set of [FieldError]s.
///
/// An empty list means the profile fields are valid. This is a pure function:
/// it performs no I/O and depends only on its arguments. [now] is the reference
/// instant used to verify that [StudentProfileInput.dateOfBirth] is strictly in
/// the past.
///
/// This checks only the profile fields. The photo is optional (no Storage is
/// provisioned); when one is supplied its size/format are validated separately
/// by [validatePhoto] (R1.8).
List<FieldError> validateStudentProfile(
  StudentProfileInput input, {
  required DateTime now,
}) {
  final List<FieldError> errors = <FieldError>[];

  if (input.fullName.trim().isEmpty) {
    errors.add(const FieldError(
      field: ProfileFields.fullName,
      message: 'Full name is required.',
    ));
  } else if (input.fullName.length > 100) {
    errors.add(const FieldError(
      field: ProfileFields.fullName,
      message: 'Full name must be at most 100 characters.',
    ));
  }

  if (input.gender == null) {
    errors.add(const FieldError(
      field: ProfileFields.gender,
      message: 'Gender is required.',
    ));
  }

  final DateTime? dob = input.dateOfBirth;
  if (dob == null) {
    errors.add(const FieldError(
      field: ProfileFields.dateOfBirth,
      message: 'Date of birth is required.',
    ));
  } else if (!dob.isBefore(now)) {
    errors.add(const FieldError(
      field: ProfileFields.dateOfBirth,
      message: 'Date of birth must be a date in the past.',
    ));
  }

  if (input.city.trim().isEmpty) {
    errors.add(const FieldError(
      field: ProfileFields.city,
      message: 'City is required.',
    ));
  } else if (input.city.length > 100) {
    errors.add(const FieldError(
      field: ProfileFields.city,
      message: 'City must be at most 100 characters.',
    ));
  }

  final int? heightCm = input.heightCm;
  if (heightCm == null) {
    errors.add(const FieldError(
      field: ProfileFields.heightCm,
      message: 'Height is required.',
    ));
  } else if (heightCm < 50 || heightCm > 250) {
    errors.add(const FieldError(
      field: ProfileFields.heightCm,
      message: 'Height must be between 50 and 250 cm.',
    ));
  }

  // The profile photo is optional in this deployment (no Firebase Storage is
  // provisioned, so uploads are skipped). When a photo *is* provided, its
  // size/format are still validated by [validatePhoto] (R1.8).

  return errors;
}

/// Validates that a profile [photo] is 5 MB or smaller and in JPEG or PNG
/// format (R1.8), returning the exact set of [FieldError]s.
///
/// An empty list means the photo is acceptable. This is a pure function that
/// inspects only the photo's size and declared content type.
List<FieldError> validatePhoto(PhotoUpload photo) {
  final List<FieldError> errors = <FieldError>[];

  if (photo.sizeBytes > maxPhotoSizeBytes) {
    errors.add(const FieldError(
      field: ProfileFields.profilePhoto,
      message: 'Profile photo must be 5 MB or smaller.',
    ));
  }

  if (!acceptedPhotoContentTypes.contains(photo.contentType.toLowerCase())) {
    errors.add(const FieldError(
      field: ProfileFields.profilePhoto,
      message: 'Profile photo must be a JPEG or PNG image.',
    ));
  }

  return errors;
}

/// Validates a [Vendor] registration [input] against the required-field rules
/// of R2.6/R2.8, returning the exact set of [FieldError]s.
///
/// An empty list means the profile fields are valid. This is a pure function:
/// it performs no I/O and depends only on its arguments. The phone number's
/// 10-digit national format is guaranteed structurally by [PhoneNumber] (R2.6),
/// so it produces no field error here. The optional fields are never validated
/// for presence (R2.7).
List<FieldError> validateVendorProfile(VendorProfileInput input) {
  final List<FieldError> errors = <FieldError>[];

  if (input.fullName.trim().isEmpty) {
    errors.add(const FieldError(
      field: ProfileFields.fullName,
      message: 'Full name is required.',
    ));
  } else if (input.fullName.length > 100) {
    errors.add(const FieldError(
      field: ProfileFields.fullName,
      message: 'Full name must be at most 100 characters.',
    ));
  }

  if (input.agencyName.trim().isEmpty) {
    errors.add(const FieldError(
      field: ProfileFields.agencyName,
      message: 'Agency name is required.',
    ));
  } else if (input.agencyName.length > 150) {
    errors.add(const FieldError(
      field: ProfileFields.agencyName,
      message: 'Agency name must be at most 150 characters.',
    ));
  }

  if (input.city.trim().isEmpty) {
    errors.add(const FieldError(
      field: ProfileFields.city,
      message: 'City is required.',
    ));
  } else if (input.city.length > 100) {
    errors.add(const FieldError(
      field: ProfileFields.city,
      message: 'City must be at most 100 characters.',
    ));
  }

  if (input.address.trim().isEmpty) {
    errors.add(const FieldError(
      field: ProfileFields.address,
      message: 'Address is required.',
    ));
  } else if (input.address.length > 250) {
    errors.add(const FieldError(
      field: ProfileFields.address,
      message: 'Address must be at most 250 characters.',
    ));
  }

  return errors;
}
