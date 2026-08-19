import '../../attendance/domain/entities/attendance_record.dart';
import 'entities/student_stats.dart';

/// PURE derivation of a student's track record from their attendance records
/// (R5.3, R5.4).
///
/// Backend-independent and property-testable: it takes plain domain
/// [AttendanceRecord]s and returns a [StudentStats]. Both the client-side
/// service (which streams the records from the repository) and any future
/// trusted aggregator can use this one definition, so the numbers a vendor sees
/// cannot drift from the numbers the student's own profile shows.
///
/// * `eventsParticipated` — how many events the student turned up to, i.e. has
///   an attendance record for. Note this counts events they *showed up* to, not
///   events they were approved for: an approved event the student ghosted
///   leaves no attendance record and is therefore invisible here.
/// * `attendanceCompleted` — how many of those they saw through, i.e. records
///   with both a check-in and a check-out ([AttendanceRecord.isCompleted]).
///
/// [records] is expected to be one student's records; any record belonging to a
/// different student is ignored rather than trusted, so a mis-scoped query can
/// never inflate someone's track record.
StudentStats deriveStudentStats({
  required String studentId,
  required List<AttendanceRecord> records,
}) {
  int participated = 0;
  int completed = 0;
  for (final AttendanceRecord record in records) {
    if (record.studentId != studentId) continue;
    participated++;
    if (record.isCompleted) completed++;
  }
  return StudentStats(
    studentId: studentId,
    eventsParticipated: participated,
    attendanceCompleted: completed,
  );
}
