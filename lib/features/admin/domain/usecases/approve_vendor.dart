import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../repositories/admin_repository.dart';

/// Approves a vendor whose approval status is `Pending`, setting it to
/// `Approved` (R6.1, R6.3).
///
/// The Pending-only guard is domain logic (see `resolveApprovalTransition`).
/// `AdminRepository.approveVendor` accepts only a vendor id, so the
/// authoritative Pending-only check is enforced by the trusted backend: when
/// invoked on a vendor that is not in a `Pending` state the repository returns
/// a [StateTransitionFailure] and the existing status is left unchanged
/// (R6.3). The pure guard is provided separately for testing and UI gating.
///
/// This use case depends only on the abstract [AdminRepository] (injected), so
/// it carries no backend types and is unit/mock testable.
class ApproveVendor {
  const ApproveVendor(this._repository);

  final AdminRepository _repository;

  /// Asks the repository to approve the vendor identified by [vendorId].
  ///
  /// Returns the updated [Vendor] (status `Approved`) on success, or a
  /// [StateTransitionFailure] when the vendor is not in a `Pending` state
  /// (R6.3).
  Future<Result<Vendor, Failure>> call(String vendorId) {
    return _repository.approveVendor(vendorId);
  }
}
