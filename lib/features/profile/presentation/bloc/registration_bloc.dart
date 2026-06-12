import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/usecases/register_student.dart';
import '../../domain/usecases/register_vendor.dart';
import '../../domain/validators/profile_validators.dart';
import 'registration_event.dart';
import 'registration_state.dart';

/// The field name used for phone-number errors the [RegistrationBloc] surfaces.
///
/// The domain validators never emit a phone error (the [PhoneNumber] value
/// object guarantees structural validity), but the BLoC must report when the
/// raw text it received cannot be parsed into one (R1.6, R2.6).
const String _phoneField = 'phone';

/// A structurally valid placeholder used only to run the field validators when
/// the entered phone text could not be parsed. The validators ignore the phone,
/// so this lets the BLoC still report every other missing/invalid field.
final PhoneNumber _placeholderPhone = PhoneNumber.national('0000000000');

/// Translates registration UI intents into [RegisterStudent]/[RegisterVendor]
/// use-case calls and emits states the form renders (design BLoC table).
///
/// The BLoC depends only on the injected use cases (never on a repository or
/// any backend package). It always re-emits the current form draft with every
/// state so the entered values are preserved across validation failures and
/// in-flight submissions, and it surfaces per-field errors via
/// [RegistrationEditing.fieldErrors] (R1.7, R2.8).
@injectable
class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  @factoryMethod
  RegistrationBloc.inject({
    required RegisterStudent registerStudent,
    required RegisterVendor registerVendor,
  }) : this(
          registerStudent: registerStudent,
          registerVendor: registerVendor,
        );

  RegistrationBloc({
    required RegisterStudent registerStudent,
    required RegisterVendor registerVendor,
    DateTime Function()? clock,
  })  : _registerStudent = registerStudent,
        _registerVendor = registerVendor,
        _now = clock ?? DateTime.now,
        super(const RegistrationEditing()) {
    on<StudentFieldsChanged>(_onStudentFieldsChanged);
    on<PhotoPicked>(_onPhotoPicked);
    on<StudentSubmitted>(_onStudentSubmitted);
    on<VendorFieldsChanged>(_onVendorFieldsChanged);
    on<VendorSubmitted>(_onVendorSubmitted);
  }

  final RegisterStudent _registerStudent;
  final RegisterVendor _registerVendor;
  final DateTime Function() _now;

  /// Replaces the held Student draft, retaining the existing Vendor draft, and
  /// clears any previously shown field errors so the user can keep editing.
  void _onStudentFieldsChanged(
    StudentFieldsChanged event,
    Emitter<RegistrationState> emit,
  ) {
    emit(RegistrationEditing(
      studentForm: event.form,
      vendorForm: state.vendorForm,
    ));
  }

  /// Updates only the photo on the held Student draft (R1.8, R1.9), retaining
  /// every other entered value.
  void _onPhotoPicked(
    PhotoPicked event,
    Emitter<RegistrationState> emit,
  ) {
    emit(RegistrationEditing(
      studentForm: state.studentForm.copyWith(
        photo: event.photo,
        clearPhoto: event.photo == null,
      ),
      vendorForm: state.vendorForm,
    ));
  }

  /// Replaces the held Vendor draft, retaining the existing Student draft, and
  /// clears any previously shown field errors.
  void _onVendorFieldsChanged(
    VendorFieldsChanged event,
    Emitter<RegistrationState> emit,
  ) {
    emit(RegistrationEditing(
      studentForm: state.studentForm,
      vendorForm: event.form,
    ));
  }

  /// Validates and registers the Student profile.
  ///
  /// The raw phone/height text is parsed first; any parse failure is reported
  /// as a field error alongside the domain validator's errors so the user sees
  /// every problem at once. On any failure the entered values are retained
  /// (R1.7).
  Future<void> _onStudentSubmitted(
    StudentSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    final StudentFormData form = state.studentForm;

    final List<FieldError> parseErrors = <FieldError>[];

    final PhoneNumber? phone = _tryParsePhone(form.phone);
    if (phone == null) {
      parseErrors.add(const FieldError(
        field: _phoneField,
        message: 'Enter a valid phone number.',
      ));
    }

    final int? heightCm = _parseHeight(form.height);

    final StudentProfileInput input = StudentProfileInput(
      fullName: form.fullName,
      phone: phone ?? _placeholderPhone,
      gender: form.gender,
      dateOfBirth: form.dateOfBirth,
      city: form.city,
      heightCm: heightCm,
      photo: form.photo,
    );

    // When the phone could not be parsed we cannot run the use case, so build
    // the full error set locally (validator + photo + phone) and stop here.
    if (phone == null) {
      final List<FieldError> errors = <FieldError>[
        ...validateStudentProfile(input, now: _now()),
        if (form.photo != null) ...validatePhoto(form.photo!),
        ...parseErrors,
      ];
      emit(RegistrationEditing(
        studentForm: form,
        vendorForm: state.vendorForm,
        fieldErrors: errors,
      ));
      return;
    }

    emit(RegistrationSubmitting(
      studentForm: form,
      vendorForm: state.vendorForm,
    ));

    final result = await _registerStudent.call(
      uid: event.uid,
      input: input,
      now: _now(),
    );

    result.fold(
      (Student _) => emit(Registered(
        studentForm: form,
        vendorForm: state.vendorForm,
      )),
      (Failure failure) => _emitFailure(emit, failure, studentForm: form),
    );
  }

  /// Validates and registers the Vendor profile, retaining entered values on
  /// any failure (R2.8).
  Future<void> _onVendorSubmitted(
    VendorSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    final VendorFormData form = state.vendorForm;

    final PhoneNumber? phone = _tryParsePhone(form.phone);

    final VendorProfileInput input = VendorProfileInput(
      fullName: form.fullName,
      agencyName: form.agencyName,
      phone: phone ?? _placeholderPhone,
      city: form.city,
      address: form.address,
      aadhaarOrPan: form.aadhaarOrPan,
      website: form.website,
      socialLinks: form.socialLinks,
    );

    if (phone == null) {
      final List<FieldError> errors = <FieldError>[
        ...validateVendorProfile(input),
        const FieldError(
          field: _phoneField,
          message: 'Enter a valid phone number.',
        ),
      ];
      emit(RegistrationEditing(
        studentForm: state.studentForm,
        vendorForm: form,
        fieldErrors: errors,
      ));
      return;
    }

    emit(RegistrationSubmitting(
      studentForm: state.studentForm,
      vendorForm: form,
    ));

    final result = await _registerVendor.call(
      uid: event.uid,
      input: input,
      now: _now(),
    );

    result.fold(
      (Vendor _) => emit(Registered(
        studentForm: state.studentForm,
        vendorForm: form,
      )),
      (Failure failure) => _emitFailure(emit, failure, vendorForm: form),
    );
  }

  /// Maps a use-case [failure] to the right state: a [ValidationFailure]
  /// becomes a [RegistrationEditing] carrying the per-field errors, while any
  /// other failure becomes a [RegistrationFailure]. Either way the entered
  /// values are retained (R1.7, R2.8).
  void _emitFailure(
    Emitter<RegistrationState> emit,
    Failure failure, {
    StudentFormData? studentForm,
    VendorFormData? vendorForm,
  }) {
    final StudentFormData student = studentForm ?? state.studentForm;
    final VendorFormData vendor = vendorForm ?? state.vendorForm;

    if (failure is ValidationFailure) {
      emit(RegistrationEditing(
        studentForm: student,
        vendorForm: vendor,
        fieldErrors: failure.fieldErrors,
      ));
      return;
    }

    emit(RegistrationFailure(
      message: failure.message,
      studentForm: student,
      vendorForm: vendor,
    ));
  }

  /// Parses [raw] into a [PhoneNumber], returning `null` when it is empty or
  /// malformed so the caller can surface a field error.
  PhoneNumber? _tryParsePhone(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return PhoneNumber.parse(trimmed);
    } on FormatException {
      return null;
    }
  }

  /// Parses [raw] height text into centimetres, returning `null` when empty or
  /// non-numeric so the domain validator reports it as missing/invalid.
  int? _parseHeight(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }
}
