import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/approval_status.dart';
import '../entities/vendor.dart';
import '../repositories/profile_repository.dart';
import '../validators/profile_validators.dart';

/// Registers a new [Vendor] profile (R2.6–R2.9, R14.3).
///
/// The flow is:
/// 1. Validate the required fields with [validateVendorProfile]. Any failure
///    short-circuits with a [ValidationFailure] carrying the exact set of
///    field errors so the presentation layer can highlight them while
///    retaining the user's input (R2.8).
/// 2. Create the [Vendor] with approval status [ApprovalStatus.pending] (R2.9)
///    via the [Vendor.create] factory, carrying any optional fields the user
///    provided (R2.7).
/// 3. Persist the [Vendor] via [ProfileRepository.createVendor] (R14.3).
///
/// This use case depends only on the abstract repository interface, so it is
/// unaffected by the choice of backend.
class RegisterVendor {
  const RegisterVendor({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository;

  final ProfileRepository _profileRepository;

  /// Validates then creates the vendor profile with a Pending approval status.
  ///
  /// [uid] is the authenticated user's id (the vendor's profile id). [now] is
  /// the reference instant used to stamp the created profile.
  Future<Result<Vendor, Failure>> call({
    required String uid,
    required VendorProfileInput input,
    required DateTime now,
  }) async {
    final List<FieldError> fieldErrors = validateVendorProfile(input);
    if (fieldErrors.isNotEmpty) {
      return Result<Vendor, Failure>.err(
        ValidationFailure(fieldErrors: fieldErrors),
      );
    }

    final Vendor vendor = Vendor.create(
      uid: uid,
      fullName: input.fullName,
      agencyName: input.agencyName,
      phone: input.phone,
      city: input.city,
      address: input.address,
      now: now,
      aadhaarOrPan: input.aadhaarOrPan,
      website: input.website,
      socialLinks: input.socialLinks,
    );

    return _profileRepository.createVendor(vendor);
  }
}
