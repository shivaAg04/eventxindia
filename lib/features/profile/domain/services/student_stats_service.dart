import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/student_stats.dart';

/// Abstract service boundary for a student's trusted track-record counters
/// (R5.3, R5.4).
///
/// Aggregating a student's history across *every* vendor's events is a trusted,
/// server-side capability rather than a client computation, for two reasons:
///
/// 1. Authority — the counters must reflect the real collection cardinalities
///    regardless of the client.
/// 2. Authorization — per-document security rules scope `applications` and
///    `attendance` reads to the owning event's vendor, so no vendor can query a
///    student's cross-event history themselves. This service is the only read
///    surface that exposes it, and it exposes just the two counts — never the
///    underlying events, check-in times, or locations.
///
/// It is implemented today by the Cloud Functions
/// `recomputeStudentStatsOnApplicationWrite` /
/// `recomputeStudentStatsOnAttendanceWrite` writing `studentStats/{studentId}`,
/// and can move to a Node.js aggregation job with no change to this interface.
abstract class StudentStatsService {
  /// Streams the latest [StudentStats] for the student identified by
  /// [studentId].
  ///
  /// Emits a new value each time the trusted service recomputes the counters.
  /// Before any aggregation has run for this student, implementations emit
  /// [StudentStats.zeroFor].
  Stream<StudentStats> watchStudentStats(String studentId);

  /// Reads the current [StudentStats] for [studentId] once.
  ///
  /// Returns the latest counters on success or a [Failure] when the read fails.
  Future<Result<StudentStats, Failure>> getStudentStats(String studentId);
}
