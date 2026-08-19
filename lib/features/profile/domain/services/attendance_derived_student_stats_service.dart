import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/domain/repositories/attendance_repository.dart';
import '../entities/student_stats.dart';
import '../student_stats_derivation.dart';
import 'student_stats_service.dart';

/// [StudentStatsService] that derives a student's track record **client-side**
/// from their attendance records (R5.3, R5.4).
///
/// This is the implementation in use today. It needs no trusted backend: a
/// vendor reviewing an applicant reads the student's `attendance` records
/// directly (security rules grant an approved vendor that read) and this service
/// reduces them with the pure [deriveStudentStats], the same way the student's
/// own profile computes its attendance figure.
///
/// Two consequences of deriving from attendance rather than from approved
/// applications, both deliberate:
///
/// 1. `eventsParticipated` counts events the student *turned up* to. An
///    approved event they ghosted leaves no attendance record and so does not
///    lower the rate.
/// 2. The reviewing vendor reads the underlying attendance documents, including
///    check-in/out times and locations — Firestore has no field-level read
///    rules, so the counts cannot be exposed without the records behind them.
///
/// Swapping to a trusted, aggregate-only source (see
/// `FirestoreStudentStatsService`, backed by the `recomputeStudentStats*` Cloud
/// Functions) restores both properties and is a single DI binding change: this
/// interface, the entity, and every screen stay untouched.
class AttendanceDerivedStudentStatsService implements StudentStatsService {
  /// Creates the service over the domain [AttendanceRepository] abstraction.
  const AttendanceDerivedStudentStatsService({
    required AttendanceRepository attendanceRepository,
  }) : _attendanceRepository = attendanceRepository;

  final AttendanceRepository _attendanceRepository;

  @override
  Stream<StudentStats> watchStudentStats(String studentId) {
    return _attendanceRepository.watchByStudent(studentId).map(
          (List<AttendanceRecord> records) => deriveStudentStats(
            studentId: studentId,
            records: records,
          ),
        );
  }

  @override
  Future<Result<StudentStats, Failure>> getStudentStats(
    String studentId,
  ) async {
    try {
      final List<AttendanceRecord> records =
          await _attendanceRepository.watchByStudent(studentId).first;
      return Result<StudentStats, Failure>.ok(
        deriveStudentStats(studentId: studentId, records: records),
      );
    } catch (_) {
      return const Result<StudentStats, Failure>.err(PersistenceFailure());
    }
  }
}
