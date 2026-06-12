import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/storage_repository.dart';

/// The raw, in-progress values of the Student registration form.
///
/// This holds exactly what the user has typed/selected so far, using plain
/// presentation types (raw [phone]/[height] strings) rather than domain value
/// objects so that partially-entered or malformed input can still be retained
/// and re-rendered after a failed submission (R1.7). The [RegistrationBloc]
/// converts this draft into a `StudentProfileInput` at submit time.
class StudentFormData extends Equatable {
  const StudentFormData({
    this.fullName = '',
    this.phone = '',
    this.gender,
    this.dateOfBirth,
    this.city = '',
    this.height = '',
    this.photo,
  });

  /// The student's full name as typed.
  final String fullName;

  /// The student's phone number as typed (not yet parsed into a value object).
  final String phone;

  /// The selected gender, or `null` when none chosen yet.
  final Gender? gender;

  /// The selected date of birth, or `null` when none chosen yet.
  final DateTime? dateOfBirth;

  /// The student's city as typed.
  final String city;

  /// The student's height in centimetres as typed (raw text).
  final String height;

  /// The chosen profile photo, or `null` when none picked yet.
  final PhotoUpload? photo;

  /// Returns a copy of this draft with the given fields replaced.
  ///
  /// Because [gender], [dateOfBirth], and [photo] are themselves nullable, this
  /// uses sentinel flags so callers can explicitly clear them when needed.
  StudentFormData copyWith({
    String? fullName,
    String? phone,
    Gender? gender,
    bool clearGender = false,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? city,
    String? height,
    PhotoUpload? photo,
    bool clearPhoto = false,
  }) {
    return StudentFormData(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      gender: clearGender ? null : (gender ?? this.gender),
      dateOfBirth:
          clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      city: city ?? this.city,
      height: height ?? this.height,
      photo: clearPhoto ? null : (photo ?? this.photo),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        fullName,
        phone,
        gender,
        dateOfBirth,
        city,
        height,
        photo,
      ];
}

/// The raw, in-progress values of the Vendor registration form.
///
/// As with [StudentFormData], values are retained verbatim so a rejected
/// submission can re-render exactly what the vendor entered (R2.8).
class VendorFormData extends Equatable {
  const VendorFormData({
    this.fullName = '',
    this.agencyName = '',
    this.phone = '',
    this.city = '',
    this.address = '',
    this.aadhaarOrPan,
    this.website,
    this.socialLinks = const <String>[],
  });

  /// The vendor's full name as typed.
  final String fullName;

  /// The vendor's agency name as typed.
  final String agencyName;

  /// The vendor's phone number as typed (not yet parsed into a value object).
  final String phone;

  /// The vendor's city as typed.
  final String city;

  /// The vendor's address as typed.
  final String address;

  /// The vendor's optional Aadhaar/PAN identifier (R2.7).
  final String? aadhaarOrPan;

  /// The vendor's optional website (R2.7).
  final String? website;

  /// The vendor's optional social links (R2.7).
  final List<String> socialLinks;

  @override
  List<Object?> get props => <Object?>[
        fullName,
        agencyName,
        phone,
        city,
        address,
        aadhaarOrPan,
        website,
        socialLinks,
      ];
}

/// The state of the Student/Vendor registration flow.
///
/// Every non-terminal state carries the current [studentForm] and [vendorForm]
/// drafts so the entered values are preserved across validation failures and
/// in-flight submissions (R1.7, R2.8). The presentation layer renders the
/// drafts and highlights any [RegistrationEditing.fieldErrors].
sealed class RegistrationState extends Equatable {
  const RegistrationState({
    this.studentForm = const StudentFormData(),
    this.vendorForm = const VendorFormData(),
  });

  /// The current Student form draft.
  final StudentFormData studentForm;

  /// The current Vendor form draft.
  final VendorFormData vendorForm;

  @override
  List<Object?> get props => <Object?>[studentForm, vendorForm];
}

/// The editing state: the user is filling in the form.
///
/// [fieldErrors] is empty while editing and is populated after a rejected
/// submission to identify each missing or invalid field, while the [studentForm]
/// / [vendorForm] retain the previously entered values (R1.7, R2.8).
class RegistrationEditing extends RegistrationState {
  const RegistrationEditing({
    super.studentForm,
    super.vendorForm,
    this.fieldErrors = const <FieldError>[],
  });

  /// The per-field validation errors to surface, empty when there are none.
  final List<FieldError> fieldErrors;

  @override
  List<Object?> get props => <Object?>[studentForm, vendorForm, fieldErrors];
}

/// A submission is in flight (validation passed; persistence is running).
class RegistrationSubmitting extends RegistrationState {
  const RegistrationSubmitting({
    super.studentForm,
    super.vendorForm,
  });
}

/// The profile was registered successfully.
class Registered extends RegistrationState {
  const Registered({
    super.studentForm,
    super.vendorForm,
  });
}

/// A non-validation failure occurred (e.g. a storage or persistence failure).
///
/// The entered values are still retained so the user can retry without
/// re-typing.
class RegistrationFailure extends RegistrationState {
  const RegistrationFailure({
    required this.message,
    super.studentForm,
    super.vendorForm,
  });

  /// A human-readable description of what went wrong.
  final String message;

  @override
  List<Object?> get props => <Object?>[studentForm, vendorForm, message];
}
