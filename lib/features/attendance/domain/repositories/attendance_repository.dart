import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/attendance_record.dart';

/// Abstract gateway for persisting and observing [AttendanceRecord]s.
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firestore, later a
/// REST/WebSocket backend) lives in the data layer. No backend types ever
/// cross this boundary — every method speaks pure domain [AttendanceRecord]
/// values and `Result<T, Failure>`.
///
/// Each record is stored under the composite id `"{eventId}_{studentId}"`
/// (R10.10), which the [checkIn] implementation must honour so a duplicate
/// check-in for the same event is rejected (R10.5) rather than silently
/// overwriting the existing record. The `accrued` flag is owned by the trusted
/// backend earnings service and is never written through this interface.
abstract class AttendanceRepository {
  /// Persists a newly created check-in [record].
  ///
  /// Implementations must create the record only when no attendance record
  /// with the same composite id already exists, leaving any existing record
  /// unchanged so a repeated check-in is rejected (R10.1, R10.5, R10.10).
  Future<Result<AttendanceRecord, Failure>> checkIn(AttendanceRecord record);

  /// Persists the completed [record] after check-out, recording the check-out
  /// time and computed working hours (R10.6, R10.9, R10.10).
  Future<Result<AttendanceRecord, Failure>> checkOut(AttendanceRecord record);

  /// Returns the attendance record identified by [attendanceId], or a failure
  /// when no such record exists.
  Future<Result<AttendanceRecord, Failure>> getById(String attendanceId);

  /// Streams the attendance records belonging to the student identified by
  /// [studentId] (R4.4).
  Stream<List<AttendanceRecord>> watchByStudent(String studentId);

  /// Streams the attendance records recorded for the event identified by
  /// [eventId].
  Stream<List<AttendanceRecord>> watchByEvent(String eventId);
}
