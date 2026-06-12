import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/money.dart';
import '../entities/earnings.dart';

/// A trusted backend capability that accrues a student's estimated earnings.
///
/// Earnings accrual must be computed exactly once and be tamper-proof, so it is
/// modelled as a **backend capability behind a service abstraction** rather
/// than as client logic. It is implemented today by a Firebase Cloud Function
/// (`accrueEarnings`, triggered on attendance writes) and can move to a Node.js
/// worker later with no change to this contract.
///
/// When a student's attendance record for an event becomes completed, the
/// event's pay-per-head is added to the student's earnings total **exactly
/// once** (R11.1): a record that has already been credited is never added
/// again (R11.2). Idempotency is keyed on `(studentId, eventId)`; the pure
/// accrual reducer that expresses this rule is property-tested independently of
/// the backend.
///
/// This abstraction speaks pure domain types only — no backend type ever
/// crosses this boundary.
abstract class EarningsService {
  /// Credits [payPerHead] to [studentId]'s estimated earnings for [eventId],
  /// returning the updated [Earnings].
  ///
  /// The operation is idempotent on `(studentId, eventId)`: invoking it again
  /// for an event that has already been credited leaves the earnings unchanged
  /// (R11.1, R11.2). Returns a [Failure] when the accrual cannot be completed.
  Future<Result<Earnings, Failure>> accrue({
    required String studentId,
    required String eventId,
    required Money payPerHead,
  });
}
