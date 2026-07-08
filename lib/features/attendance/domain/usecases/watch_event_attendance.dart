import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

/// Streams the [AttendanceRecord]s recorded for a single event, for the owning
/// vendor's attendance view (R5.7).
///
/// The stream re-emits whenever a student checks in or out of the event; an
/// empty list signals that no one has checked in yet, which the presentation
/// layer renders as an empty-list indication (R5.7).
class WatchEventAttendance {
  const WatchEventAttendance({required AttendanceRepository repository})
      : _repository = repository;

  final AttendanceRepository _repository;

  /// Returns the stream of attendance records for the event identified by
  /// [eventId].
  Stream<List<AttendanceRecord>> call(String eventId) =>
      _repository.watchByEvent(eventId);
}
