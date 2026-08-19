import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/student_stats.dart';
import '../../domain/services/student_stats_service.dart';
import '../datasources/firestore_student_stats_data_source.dart';

/// Client-side binding for the trusted [StudentStatsService] (R5.3, R5.4).
///
/// **Not currently wired.** The active binding is
/// `AttendanceDerivedStudentStatsService`, which derives the counters in the app
/// from attendance records and needs no deployed backend. Switch to this one —
/// restoring aggregate-only exposure and the "approved events" denominator — by
/// pointing the `studentStatsService` provider in `core/di/use_case_module.dart`
/// at this class once the `recomputeStudentStats*` Cloud Functions are deployed
/// (they require the project to be on the Blaze plan), then tightening the
/// `attendance` read rule back to the owning vendor.
///
/// A student's cross-event track record is aggregated **server-side** — today
/// the `recomputeStudentStats*` Cloud Functions writing
/// `studentStats/{studentId}` — so the client never derives the counters; it
/// only reads the document the backend maintains. This implementation provides
/// that read surface over [FirestoreStudentStatsDataSource], mapping each
/// snapshot to the pure [StudentStats] entity.
///
/// Before any aggregation has run for a student (a missing or empty document)
/// it yields [StudentStats.zeroFor], matching the contract. No backend type
/// crosses this boundary — the implementation speaks pure domain [StudentStats]
/// and `Result<T, Failure>` only.
class FirestoreStudentStatsService implements StudentStatsService {
  /// Creates the service over the injected [FirestoreStudentStatsDataSource].
  const FirestoreStudentStatsService(this._dataSource);

  final FirestoreStudentStatsDataSource _dataSource;

  @override
  Stream<StudentStats> watchStudentStats(String studentId) {
    return _dataSource
        .watchByStudent(studentId)
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) =>
            _toEntity(studentId, snapshot));
  }

  @override
  Future<Result<StudentStats, Failure>> getStudentStats(
    String studentId,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _dataSource.getByStudent(studentId);
      return Result<StudentStats, Failure>.ok(_toEntity(studentId, snapshot));
    } catch (_) {
      return const Result<StudentStats, Failure>.err(PersistenceFailure());
    }
  }

  /// Converts a `studentStats/{studentId}` snapshot into a domain
  /// [StudentStats], falling back to zero counters when the document does not
  /// exist or a counter is absent (no aggregation has run for this student yet).
  StudentStats _toEntity(
    String studentId,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return StudentStats.zeroFor(studentId);
    }
    return StudentStats(
      studentId: studentId,
      eventsParticipated: _readCount(data['eventsParticipated']),
      attendanceCompleted: _readCount(data['attendanceCompleted']),
    );
  }

  /// Reads a non-negative counter from a raw Firestore value, treating a
  /// missing or negative value as zero so [StudentStats] never sees a negative
  /// count.
  static int _readCount(Object? raw) {
    final int value = raw is num ? raw.toInt() : 0;
    return value < 0 ? 0 : value;
  }
}
