import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/student.dart';
import '../repositories/profile_repository.dart';
import '../repositories/storage_repository.dart';
import '../validators/profile_validators.dart';

/// Registers a new [Student] profile (R1.6–R1.9, R14.1, R14.2).
///
/// The flow is:
/// 1. Validate the profile fields with [validateStudentProfile] and, when a
///    photo is present, its size/format with [validatePhoto]. Any failure
///    short-circuits with a [ValidationFailure] carrying the exact set of
///    field errors so the presentation layer can highlight them while
///    retaining the user's input (R1.7).
/// 2. Upload the photo via [StorageRepository.uploadProfilePhoto] (R1.9,
///    R14.1). The upload precedes profile creation so the stored reference can
///    be embedded in the persisted [Student].
/// 3. Persist the [Student] via [ProfileRepository.createStudent] (R14.2).
///
/// This use case depends only on the abstract repository interfaces, so it is
/// unaffected by the choice of backend.
class RegisterStudent {
  const RegisterStudent({
    required ProfileRepository profileRepository,
    required StorageRepository storageRepository,
  })  : _profileRepository = profileRepository,
        _storageRepository = storageRepository;

  final ProfileRepository _profileRepository;
  final StorageRepository _storageRepository;

  /// Validates, uploads the photo, then creates the student profile.
  ///
  /// [uid] is the authenticated user's id (the student's profile id). [now] is
  /// the reference instant used both to validate the date of birth and to
  /// stamp the created profile.
  Future<Result<Student, Failure>> call({
    required String uid,
    required StudentProfileInput input,
    required DateTime now,
  }) async {
    final List<FieldError> fieldErrors = <FieldError>[
      ...validateStudentProfile(input, now: now),
    ];

    // Only validate the photo's size/format when one was actually provided;
    // its absence is already reported by validateStudentProfile.
    final PhotoUpload? photo = input.photo;
    if (photo != null) {
      fieldErrors.addAll(validatePhoto(photo));
    }

    if (fieldErrors.isNotEmpty) {
      return Result<Student, Failure>.err(
        ValidationFailure(fieldErrors: fieldErrors),
      );
    }

    // Safe: validation above guarantees the photo is present and valid.
    final PhotoUpload validPhoto = photo!;

    // The photo upload precedes profile creation so the stored reference can
    // be embedded in the persisted student (R1.9).
    final Result<String, Failure> uploadResult =
        await _storageRepository.uploadProfilePhoto(
      uid: uid,
      photo: validPhoto,
    );

    final String? photoPath = uploadResult.valueOrNull;
    if (photoPath == null) {
      return Result<Student, Failure>.err(uploadResult.failureOrNull!);
    }

    final Student student = Student(
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
    );

    return _profileRepository.createStudent(student);
  }
}
