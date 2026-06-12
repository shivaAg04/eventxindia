import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';
import '../working_hours.dart';

/// Records a student's check-out of an event using the vendor's end code
/// (R10.6, R10.7, R10.8, R10.9, R10.10).
///
/// The flow is a railway of guards, and **any** rejection leaves the existing
/// attendance record unchanged (R10.7, R10.8):
///
/// 1. Load the event. A missing event short-circuits with the repository's
///    failure (typically a [NotFoundFailure]).
/// 2. The submitted [endCode] must equal the event's generated
///    [Event.endCode]; otherwise a [ValidationFailure] (R10.7). A `null` event
///    code (never generated) never matches.
/// 3. Load the student's attendance record; a check-in must already be
///    recorded, otherwise a [StateTransitionFailure] (R10.8). A missing record
///    is treated the same as a missing check-in.
/// 4. On success the [workingHours] are computed from the check-in and
///    check-out times (rounded to two decimal places, non-negative; R10.9),
///    the record is completed at [now], and persisted via
///    [AttendanceRepository.checkOut] (R10.6, R10.10).
///
/// This is pure domain logic: it depends only on the repository abstractions
/// and a [now] clock, never on any backend type.
class CheckOut {
  /// Creates the use case with its injected [AttendanceRepository],
  /// [EventRepository], and a [now] clock used to timestamp the check-out.
  const CheckOut({
    required AttendanceRepository attendanceRepository,
    required EventRepository eventRepository,
    required DateTime Function() now,
  })  : _attendanceRepository = attendanceRepository,
        _eventRepository = eventRepository,
        _now = now;

  final AttendanceRepository _attendanceRepository;
  final EventRepository _eventRepository;
  final DateTime Function() _now;

  /// Checks [studentId] out of the event identified by [eventId].
  ///
  /// [endCode] is the code the student entered. Returns the completed
  /// [AttendanceRecord] on success, or a [Failure] when the event does not
  /// exist, the code is invalid (R10.7), or no check-in exists (R10.8).
  Future<Result<AttendanceRecord, Failure>> call({
    required String studentId,
    required String eventId,
    required String endCode,
  }) async {
    final Result<Event, Failure> eventResult =
        await _eventRepository.getById(eventId);

    final Event? event = eventResult.valueOrNull;
    if (event == null) {
      return Result<AttendanceRecord, Failure>.err(
        eventResult.failureOrNull ?? const NotFoundFailure(),
      );
    }

    // R10.7: the end code must match the event's generated end code.
    if (event.endCode == null || event.endCode != endCode) {
      return const Result<AttendanceRecord, Failure>.err(
        ValidationFailure(
          message: 'The end code is invalid.',
          fieldErrors: <FieldError>[
            FieldError(field: 'endCode', message: 'Invalid end code.'),
          ],
        ),
      );
    }

    // R10.8: a check-in must already be recorded for this student.
    final String attendanceId = AttendanceRecord.buildId(
      eventId: eventId,
      studentId: studentId,
    );
    final Result<AttendanceRecord, Failure> existingResult =
        await _attendanceRepository.getById(attendanceId);
    final AttendanceRecord? existing = existingResult.valueOrNull;
    if (existing == null || !existing.isCheckedIn) {
      return const Result<AttendanceRecord, Failure>.err(
        StateTransitionFailure(
          message: 'You have not checked in to this event.',
        ),
      );
    }

    // R10.6, R10.9, R10.10: compute working hours, complete the record, persist.
    final DateTime checkOutTime = _now();
    final AttendanceRecord completed = existing.checkOut(
      checkOutTime: checkOutTime,
      workingHours: workingHours(existing.checkInTime!, checkOutTime),
    );

    return _attendanceRepository.checkOut(completed);
  }
}
