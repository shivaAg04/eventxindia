import '../entities/earnings.dart';
import '../repositories/earnings_repository.dart';

/// Streams a student's estimated [Earnings] for the earnings screen and the
/// student dashboard (R11.3, R11.4, R11.5).
///
/// Delegates to [EarningsRepository.watchByStudent], emitting the current
/// [Earnings] projection for [studentId] and a fresh value whenever it changes.
/// The emitted [Earnings] carries the monetary [Earnings.total] (R11.3) and the
/// per-event credited amounts in [Earnings.perEvent] (R11.4). A student with no
/// completed attendance records yields an empty projection — zero total and an
/// empty per-event map (R11.5).
///
/// Earnings are read-only on the client: accrual is performed exactly once by
/// the trusted backend [EarningsService] (R11.1, R11.2). This use case is pure
/// domain logic, depending only on the repository abstraction and never on any
/// backend type.
class GetEarnings {
  /// Creates the use case with its injected [EarningsRepository].
  const GetEarnings({required EarningsRepository earningsRepository})
      : _earningsRepository = earningsRepository;

  final EarningsRepository _earningsRepository;

  /// Streams the estimated earnings of the student identified by [studentId].
  Stream<Earnings> call({required String studentId}) =>
      _earningsRepository.watchByStudent(studentId);
}
