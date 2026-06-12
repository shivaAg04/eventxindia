import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/geo_point.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../entities/attendance_record.dart';
import '../geo_distance.dart';
import '../repositories/attendance_repository.dart';

/// The maximum distance, in meters, a student's device may be from the event
/// location for a check-in to be accepted (R10.3).
const double kCheckInRadiusMeters = 100.0;

/// Records a student's check-in to an event using the vendor's start code and a
/// GPS-validated device location (R10.1–R10.5, R10.10).
///
/// Device-location acquisition (including the 30-second timeout of R10.4) is
/// performed by the caller and supplied as [deviceLocation]: an `Ok` carries
/// the acquired coordinate, while an `Err` represents a failed acquisition —
/// for a timeout the caller supplies a [LocationFailure] indicating the device
/// location is unavailable. The use case stays pure: it owns no clocks, timers,
/// or platform APIs.
///
/// The flow is a railway of guards, and **any** rejection leaves an existing
/// attendance record unchanged (R10.2–R10.5):
///
/// 1. Load the event. A missing event short-circuits with the repository's
///    failure (typically a [NotFoundFailure]).
/// 2. The submitted [startCode] must equal the event's generated
///    [Event.startCode]; otherwise a [ValidationFailure] (R10.2). A `null`
///    event code (never generated) never matches.
/// 3. [deviceLocation] must be an `Ok`; an `Err` (e.g. the 30s timeout) is
///    propagated as a [LocationFailure] indicating the location is unavailable
///    (R10.4).
/// 4. The acquired location must be within [kCheckInRadiusMeters] of the event
///    location; otherwise a [LocationFailure] (R10.3).
/// 5. If an attendance record already exists with a check-in recorded, the
///    request is rejected with a [StateTransitionFailure] and the existing
///    record is left unchanged (R10.5).
/// 6. On success a new [AttendanceRecord] is built at [now] and persisted via
///    [AttendanceRepository.checkIn] (R10.1, R10.10).
///
/// This is pure domain logic: it depends only on the repository abstractions
/// and a [now] clock, never on any backend type.
class CheckIn {
  /// Creates the use case with its injected [AttendanceRepository],
  /// [EventRepository], and a [now] clock used to timestamp the check-in.
  const CheckIn({
    required AttendanceRepository attendanceRepository,
    required EventRepository eventRepository,
    required DateTime Function() now,
  })  : _attendanceRepository = attendanceRepository,
        _eventRepository = eventRepository,
        _now = now;

  final AttendanceRepository _attendanceRepository;
  final EventRepository _eventRepository;
  final DateTime Function() _now;

  /// Checks [studentId] in to the event identified by [eventId].
  ///
  /// [startCode] is the code the student entered and [deviceLocation] is the
  /// result of the caller's location acquisition (an `Err` represents a failed
  /// or timed-out acquisition).
  ///
  /// Returns the persisted [AttendanceRecord] on success, or a [Failure] when
  /// the event does not exist, the code is invalid (R10.2), the location is
  /// unavailable (R10.4) or out of range (R10.3), or the student is already
  /// checked in (R10.5).
  Future<Result<AttendanceRecord, Failure>> call({
    required String studentId,
    required String eventId,
    required String startCode,
    required Result<GeoPoint, Failure> deviceLocation,
  }) async {
    final Result<Event, Failure> eventResult =
        await _eventRepository.getById(eventId);

    final Event? event = eventResult.valueOrNull;
    if (event == null) {
      return Result<AttendanceRecord, Failure>.err(
        eventResult.failureOrNull ?? const NotFoundFailure(),
      );
    }

    // R10.2: the start code must match the event's generated start code.
    if (event.startCode == null || event.startCode != startCode) {
      return const Result<AttendanceRecord, Failure>.err(
        ValidationFailure(
          message: 'The start code is invalid.',
          fieldErrors: <FieldError>[
            FieldError(field: 'startCode', message: 'Invalid start code.'),
          ],
        ),
      );
    }

    // R10.4: device location must have been acquired; a timeout/failure is
    // surfaced as a location-unavailable failure.
    final GeoPoint? location = deviceLocation.valueOrNull;
    if (location == null) {
      return Result<AttendanceRecord, Failure>.err(
        deviceLocation.failureOrNull ??
            const LocationFailure(
              message: 'Your device location is unavailable.',
            ),
      );
    }

    // R10.3: the device must be within the acceptance radius of the event.
    if (distanceMeters(location, event.location.geo) > kCheckInRadiusMeters) {
      return const Result<AttendanceRecord, Failure>.err(
        LocationFailure(
          message: 'You are too far from the event location to check in.',
        ),
      );
    }

    // R10.5: reject a repeated check-in, leaving any existing record unchanged.
    final String attendanceId = AttendanceRecord.buildId(
      eventId: eventId,
      studentId: studentId,
    );
    final Result<AttendanceRecord, Failure> existingResult =
        await _attendanceRepository.getById(attendanceId);
    final AttendanceRecord? existing = existingResult.valueOrNull;
    if (existing != null && existing.isCheckedIn) {
      return const Result<AttendanceRecord, Failure>.err(
        StateTransitionFailure(
          message: 'You are already checked in to this event.',
        ),
      );
    }

    // R10.1, R10.10: record the check-in and persist it.
    final AttendanceRecord record = AttendanceRecord.checkIn(
      eventId: eventId,
      studentId: studentId,
      checkInTime: _now(),
      checkInGeo: location,
    );

    return _attendanceRepository.checkIn(record);
  }
}
