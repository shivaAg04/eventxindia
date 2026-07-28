import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/validators/profile_validators.dart';
import 'registration_event.dart';
import 'registration_state.dart';

/// The field name used for phone-number errors the BLoC surfaces. The domain
/// validators never emit one (the [PhoneNumber] value object guarantees
/// structural validity), so the BLoC reports unparseable raw text itself.
const String _phoneField = 'phone';

/// A structurally valid placeholder used only to run the field validators when
/// the entered phone text could not be parsed; the validators ignore the phone.
final PhoneNumber _placeholderPhone = PhoneNumber.national('0000000000');

/// Drives the registration form: validates input, uploads the photo, and
/// persists the profile directly through the repositories (R1.6–R1.9, R2.6–R2.9,
/// R14.1–R14.3). Every state re-emits the current draft so entered values are
/// retained across validation failures and in-flight submissions (R1.7, R2.8).
@injectable
class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  @factoryMethod
  RegistrationBloc.inject({
    required ProfileRepository profileRepository,
    required StorageRepository storageRepository,
  }) : this(
          profileRepository: profileRepository,
          storageRepository: storageRepository,
        );

  RegistrationBloc({
    required ProfileRepository profileRepository,
    required StorageRepository storageRepository,
    DateTime Function()? clock,
  })  : _profileRepository = profileRepository,
        _storageRepository = storageRepository,
        _now = clock ?? DateTime.now,
        super(const RegistrationEditing()) {
    on<StudentFieldsChanged>(_onStudentFieldsChanged);
    on<PhotoPicked>(_onPhotoPicked);
    on<StudentSubmitted>(_onStudentSubmitted);
    on<VendorFieldsChanged>(_onVendorFieldsChanged);
    on<VendorSubmitted>(_onVendorSubmitted);
  }

  final ProfileRepository _profileRepository;
  final StorageRepository _storageRepository;
  final DateTime Function() _now;

  void _onStudentFieldsChanged(
    StudentFieldsChanged event,
    Emitter<RegistrationState> emit,
  ) {
    emit(RegistrationEditing(
      studentForm: event.form,
      vendorForm: state.vendorForm,
    ));
  }

  void _onPhotoPicked(PhotoPicked event, Emitter<RegistrationState> emit) {
    emit(RegistrationEditing(
      studentForm: state.studentForm.copyWith(
        photo: event.photo,
        clearPhoto: event.photo == null,
      ),
      vendorForm: state.vendorForm,
    ));
  }

  void _onVendorFieldsChanged(
    VendorFieldsChanged event,
    Emitter<RegistrationState> emit,
  ) {
    emit(RegistrationEditing(
      studentForm: state.studentForm,
      vendorForm: event.form,
    ));
  }

  /// Validates, uploads the photo, and persists the Student profile, retaining
  /// entered values on any failure (R1.7).
  Future<void> _onStudentSubmitted(
    StudentSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    final StudentFormData form = state.studentForm;
    final PhoneNumber? phone = _tryParsePhone(form.phone);

    final StudentProfileInput input = StudentProfileInput(
      fullName: form.fullName,
      phone: phone ?? _placeholderPhone,
      gender: form.gender,
      dateOfBirth: form.dateOfBirth,
      city: form.city,
      heightCm: _parseHeight(form.height),
      photo: form.photo,
    );

    // Without a parseable phone we cannot persist, so report every field
    // problem (validator + photo + phone) at once and stop.
    if (phone == null) {
      emit(RegistrationEditing(
        studentForm: form,
        vendorForm: state.vendorForm,
        fieldErrors: <FieldError>[
          ...validateStudentProfile(input, now: _now()),
          if (form.photo != null) ...validatePhoto(form.photo!),
          const FieldError(field: _phoneField, message: 'Enter a valid phone number.'),
        ],
      ));
      return;
    }

    emit(RegistrationSubmitting(studentForm: form, vendorForm: state.vendorForm));

    final Result<Student, Failure> result =
        await _createStudent(uid: event.uid, input: input);
    result.fold(
      (Student _) =>
          emit(Registered(studentForm: form, vendorForm: state.vendorForm)),
      (Failure failure) => _emitFailure(emit, failure, studentForm: form),
    );
  }

  /// Validates then persists the Vendor profile with a Pending approval status,
  /// retaining entered values on any failure (R2.8, R2.9).
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
      emit(RegistrationEditing(
        studentForm: state.studentForm,
        vendorForm: form,
        fieldErrors: <FieldError>[
          ...validateVendorProfile(input),
          const FieldError(field: _phoneField, message: 'Enter a valid phone number.'),
        ],
      ));
      return;
    }

    emit(RegistrationSubmitting(studentForm: state.studentForm, vendorForm: form));

    final Result<Vendor, Failure> result =
        await _createVendor(uid: event.uid, input: input);
    result.fold(
      (Vendor _) =>
          emit(Registered(studentForm: state.studentForm, vendorForm: form)),
      (Failure failure) => _emitFailure(emit, failure, vendorForm: form),
    );
  }

  /// Validates the input, uploads the photo when present, then persists the
  /// Student. Returns the first [Failure] encountered (R1.6–R1.9, R14.1, R14.2).
  Future<Result<Student, Failure>> _createStudent({
    required String uid,
    required StudentProfileInput input,
  }) async {
    final DateTime now = _now();
    final List<FieldError> errors = <FieldError>[
      ...validateStudentProfile(input, now: now),
      if (input.photo != null) ...validatePhoto(input.photo!),
    ];
    if (errors.isNotEmpty) {
      return Result<Student, Failure>.err(ValidationFailure(fieldErrors: errors));
    }

    // Photo upload is best-effort: a photo is optional (R1.9), so if the upload
    // fails (e.g. Firebase Storage not set up, or a flaky connection) we still
    // complete registration without a photo rather than blocking the user. The
    // student can add a photo later once Storage is available.
    String photoPath = '';
    if (input.photo != null) {
      final Result<String, Failure> upload =
          await _storageRepository.uploadProfilePhoto(uid: uid, photo: input.photo!);
      photoPath = upload.valueOrNull ?? '';
    }

    return _profileRepository.createStudent(Student(
      uid: uid,
      fullName: input.fullName,
      phone: input.phone,
      gender: input.gender!,
      dateOfBirth: input.dateOfBirth!,
      city: input.city,
      heightCm: input.heightCm!,
      profilePhotoPath: photoPath,
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// Validates the input then persists the Vendor with a Pending approval
  /// status (R2.6–R2.9, R14.3).
  Future<Result<Vendor, Failure>> _createVendor({
    required String uid,
    required VendorProfileInput input,
  }) async {
    final List<FieldError> errors = validateVendorProfile(input);
    if (errors.isNotEmpty) {
      return Result<Vendor, Failure>.err(ValidationFailure(fieldErrors: errors));
    }

    return _profileRepository.createVendor(Vendor.create(
      uid: uid,
      fullName: input.fullName,
      agencyName: input.agencyName,
      phone: input.phone,
      city: input.city,
      address: input.address,
      now: _now(),
      aadhaarOrPan: input.aadhaarOrPan,
      website: input.website,
      socialLinks: input.socialLinks,
    ));
  }

  /// A [ValidationFailure] becomes [RegistrationEditing] with per-field errors;
  /// any other failure becomes [RegistrationFailure]. Entered values are kept.
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

  /// Parses [raw] into a [PhoneNumber], or `null` when empty/malformed.
  PhoneNumber? _tryParsePhone(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      return PhoneNumber.parse(trimmed);
    } on FormatException {
      return null;
    }
  }

  /// Parses [raw] height text into centimetres, or `null` when empty/non-numeric.
  int? _parseHeight(String raw) {
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }
}
