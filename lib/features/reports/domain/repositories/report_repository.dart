import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/report.dart';

/// Abstract gateway for persisting and observing [Report] records (R12).
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firestore, later a
/// REST backend) lives in the data layer. No backend types ever cross this
/// boundary — every method speaks pure domain [Report] values and
/// `Result<T, Failure>`.
abstract class ReportRepository {
  /// Persists a newly submitted [report] (R12.1, R12.2, R12.5).
  ///
  /// Returns the stored [Report] on success, or a [Failure] when the write
  /// fails.
  Future<Result<Report, Failure>> submit(Report report);

  /// Streams every submitted report for the admin reports view (R6.8, R12.6).
  Stream<List<Report>> watchAll();
}
