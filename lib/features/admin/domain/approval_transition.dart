import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/value_objects/approval_status.dart';

/// An admin's decision on a vendor's approval (R6.1, R6.2).
enum ApprovalDecision {
  /// Approve the vendor, moving it to [ApprovalStatus.approved] (R6.1).
  approve,

  /// Reject the vendor, moving it to [ApprovalStatus.rejected] (R6.2).
  reject,
}

/// The pure Pending-only guard for vendor approval transitions
/// (R6.1, R6.2, R6.3).
///
/// This is domain logic expressed as a pure, side-effect-free function so it
/// can be exercised exhaustively by property tests and reused by the
/// presentation layer to pre-check an action. It encodes the rule that an
/// approval transition is permitted only while the vendor's current status is
/// [ApprovalStatus.pending]:
///
/// - When [current] is [ApprovalStatus.pending], returns the target status —
///   [ApprovalStatus.approved] for [ApprovalDecision.approve] (R6.1) or
///   [ApprovalStatus.rejected] for [ApprovalDecision.reject] (R6.2).
/// - Otherwise returns a [StateTransitionFailure] and the existing status is
///   left unchanged (R6.3).
///
/// The trusted backend enforces this same rule authoritatively (the client is
/// not the source of truth for approval status); the
/// `AdminRepository.approveVendor`/`rejectVendor` calls return a
/// [StateTransitionFailure] when invoked on a non-Pending vendor. This guard
/// provides the equivalent pure decision for domain testing and UI gating.
Result<ApprovalStatus, Failure> resolveApprovalTransition(
  ApprovalStatus current,
  ApprovalDecision decision,
) {
  if (current != ApprovalStatus.pending) {
    return Result<ApprovalStatus, Failure>.err(
      const StateTransitionFailure(
        message: 'The vendor is not in a Pending state.',
      ),
    );
  }

  final ApprovalStatus next = switch (decision) {
    ApprovalDecision.approve => ApprovalStatus.approved,
    ApprovalDecision.reject => ApprovalStatus.rejected,
  };
  return Result<ApprovalStatus, Failure>.ok(next);
}
