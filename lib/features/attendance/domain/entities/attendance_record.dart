import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/geo_point.dart';

/// A student's attendance for a single event: check-in/out times, the geo
/// coordinates captured at each action, the computed working hours, and the
/// backend-managed [accrued] flag.
///
/// An attendance record is uniquely identified by the composite
/// [attendanceId] `"{eventId}_{studentId}"`, which doubles as the natural
/// dedupe key so a student has at most one attendance record per event and a
/// repeated check-in is rejected rather than duplicated (R10.5, R10.10).
///
/// The lifecycle is two-phase: a record is first created at check-in with a
/// [checkInTime] and optional [checkInGeo] (R10.1), then completed at check-out
/// with a [checkOutTime], optional [checkOutGeo], and a [workingHours] value
/// rounded to two decimal places (R10.6, R10.9). Until check-out those fields
/// are `null`.
///
/// The [accrued] flag is owned by the trusted backend earnings service (it is
/// set true exactly once when a completed record is credited). The client never
/// writes it; it is read-only domain state carried for display/idempotency
/// reasoning only.
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values and the backend-neutral [GeoPoint] value object only, so it is
/// unaffected by a future change of backend.
class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.attendanceId,
    required this.eventId,
    required this.studentId,
    this.checkInTime,
    this.checkInGeo,
    this.checkOutTime,
    this.checkOutGeo,
    this.workingHours,
    this.accrued = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a brand-new attendance record at check-in for [studentId] against
  /// [eventId].
  ///
  /// The [attendanceId] is derived as the composite key
  /// `"{eventId}_{studentId}"`. The [checkInTime] is recorded and the optional
  /// [checkInGeo] captures the validated device location (R10.1). The
  /// [createdAt] and [updatedAt] timestamps are both initialised to
  /// [checkInTime], and [accrued] defaults to `false`.
  factory AttendanceRecord.checkIn({
    required String eventId,
    required String studentId,
    required DateTime checkInTime,
    GeoPoint? checkInGeo,
  }) {
    return AttendanceRecord(
      attendanceId: buildId(eventId: eventId, studentId: studentId),
      eventId: eventId,
      studentId: studentId,
      checkInTime: checkInTime,
      checkInGeo: checkInGeo,
      createdAt: checkInTime,
      updatedAt: checkInTime,
    );
  }

  /// The composite identifier `"{eventId}_{studentId}"`.
  ///
  /// This is the document id used for persistence and the natural dedupe key
  /// for "at most one attendance record per student per event" (R10.10).
  final String attendanceId;

  /// The id of the event this attendance is for.
  final String eventId;

  /// The id of the attending student.
  final String studentId;

  /// When the student checked in, or `null` before check-in.
  final DateTime? checkInTime;

  /// The device location captured and validated at check-in, or `null`.
  final GeoPoint? checkInGeo;

  /// When the student checked out, or `null` before check-out.
  final DateTime? checkOutTime;

  /// The device location captured at check-out, or `null`.
  final GeoPoint? checkOutGeo;

  /// The working hours, rounded to two decimal places, set at check-out
  /// (R10.9). `null` until the record is completed.
  final double? workingHours;

  /// Whether the completed record has been credited to the student's earnings.
  ///
  /// Owned and set exactly once by the trusted backend earnings service; the
  /// client never writes this value (R11.1, R11.2).
  final bool accrued;

  /// When the record was created (at check-in).
  final DateTime createdAt;

  /// When the record was last updated.
  final DateTime updatedAt;

  /// Whether the student has checked in.
  bool get isCheckedIn => checkInTime != null;

  /// Whether the record is completed (both check-in and check-out recorded).
  bool get isCompleted => checkInTime != null && checkOutTime != null;

  /// Builds the composite attendance id from [eventId] and [studentId].
  static String buildId({
    required String eventId,
    required String studentId,
  }) =>
      '${eventId}_$studentId';

  /// Returns a copy of this record completed at check-out with [checkOutTime],
  /// the optional [checkOutGeo], and the computed [workingHours] (R10.6,
  /// R10.9). The [updatedAt] timestamp is advanced to [checkOutTime].
  AttendanceRecord checkOut({
    required DateTime checkOutTime,
    required double workingHours,
    GeoPoint? checkOutGeo,
  }) {
    return copyWith(
      checkOutTime: checkOutTime,
      checkOutGeo: checkOutGeo,
      workingHours: workingHours,
      updatedAt: checkOutTime,
    );
  }

  /// Returns a copy of this record with the given fields replaced.
  AttendanceRecord copyWith({
    DateTime? checkInTime,
    GeoPoint? checkInGeo,
    DateTime? checkOutTime,
    GeoPoint? checkOutGeo,
    double? workingHours,
    bool? accrued,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      attendanceId: attendanceId,
      eventId: eventId,
      studentId: studentId,
      checkInTime: checkInTime ?? this.checkInTime,
      checkInGeo: checkInGeo ?? this.checkInGeo,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkOutGeo: checkOutGeo ?? this.checkOutGeo,
      workingHours: workingHours ?? this.workingHours,
      accrued: accrued ?? this.accrued,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        attendanceId,
        eventId,
        studentId,
        checkInTime,
        checkInGeo,
        checkOutTime,
        checkOutGeo,
        workingHours,
        accrued,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() => 'AttendanceRecord('
      'attendanceId: $attendanceId, '
      'eventId: $eventId, '
      'studentId: $studentId, '
      'checkInTime: $checkInTime, '
      'checkInGeo: $checkInGeo, '
      'checkOutTime: $checkOutTime, '
      'checkOutGeo: $checkOutGeo, '
      'workingHours: $workingHours, '
      'accrued: $accrued, '
      'createdAt: $createdAt, '
      'updatedAt: $updatedAt)';
}
