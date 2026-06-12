import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/earnings.dart';

/// Read-only gateway for observing a student's [Earnings].
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firestore, later a
/// REST/WebSocket backend) lives in the data layer. No backend types ever
/// cross this boundary — every method speaks pure domain [Earnings] values and
/// `Result<T, Failure>`.
///
/// The client never *writes* earnings: accrual is performed exactly once by
/// the trusted [EarningsService] backend capability (R11.1, R11.2), so this
/// repository exposes reads only.
abstract class EarningsRepository {
  /// Streams the [Earnings] of the student identified by [studentId].
  ///
  /// Emits an empty projection (zero total, empty per-event map) while the
  /// student has no completed attendance records (R11.5).
  Stream<Earnings> watchByStudent(String studentId);

  /// Returns the current [Earnings] of the student identified by [studentId],
  /// or a failure when the data cannot be retrieved.
  ///
  /// Yields an empty projection (zero total, empty per-event map) when the
  /// student has no completed attendance records (R11.5).
  Future<Result<Earnings, Failure>> getByStudent(String studentId);
}
