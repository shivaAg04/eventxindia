import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/value_objects/geo_point.dart';
import '../../domain/entities/attendance_record.dart';

/// Firebase data-transfer object for an `attendance/{eventId}_{studentId}`
/// document.
///
/// This is the only place Firebase types (`DocumentSnapshot`, `Timestamp`, and
/// Firestore's own `GeoPoint`) touch the [AttendanceRecord] shape. The DTO
/// parses a Firestore document into plain Dart fields ([fromFirestore]),
/// serialises back to a Firestore-ready map ([toFirestore]), and converts
/// to/from the pure domain [AttendanceRecord] entity
/// ([toEntity]/[AttendanceDto.fromEntity]) — mapping `checkInTime`/
/// `checkOutTime` Firestore `Timestamp`s to/from [DateTime], `checkInGeo`/
/// `checkOutGeo` Firestore [fs.GeoPoint]s to/from the backend-neutral
/// [GeoPoint] value object, and `workingHours` as a plain number (design
/// "Data Models" / "DTO / Mapper Pattern").
///
/// CRITICAL: the `accrued` flag is owned by the trusted backend earnings
/// service and is **never** written by the client. [toFirestore] therefore
/// omits `accrued` entirely so a client write can never create or mutate it
/// (R11.1, R11.2, security rules). The DTO still *reads* `accrued` on the way
/// in for display/idempotency reasoning.
class AttendanceDto {
  const AttendanceDto({
    required this.attendanceId,
    required this.eventId,
    required this.studentId,
    required this.createdAt,
    required this.updatedAt,
    this.checkInTime,
    this.checkInGeo,
    this.checkOutTime,
    this.checkOutGeo,
    this.workingHours,
    this.accrued = false,
  });

  /// The composite identifier `"{eventId}_{studentId}"` (matches the doc id).
  final String attendanceId;

  /// The id of the event this attendance is for.
  final String eventId;

  /// The id of the attending student.
  final String studentId;

  /// When the student checked in, or `null` before check-in.
  final DateTime? checkInTime;

  /// The device location captured at check-in, or `null`.
  final GeoPoint? checkInGeo;

  /// When the student checked out, or `null` before check-out.
  final DateTime? checkOutTime;

  /// The device location captured at check-out, or `null`.
  final GeoPoint? checkOutGeo;

  /// The working hours rounded to two decimal places, or `null` until
  /// check-out.
  final double? workingHours;

  /// Whether the completed record has been credited (backend-owned, read-only
  /// for the client).
  final bool accrued;

  /// When the record was created (at check-in).
  final DateTime createdAt;

  /// When the record was last updated.
  final DateTime updatedAt;

  /// Parses a Firestore `attendance/{id}` document into an [AttendanceDto].
  factory AttendanceDto.fromFirestore(fs.DocumentSnapshot<Object?> doc) {
    final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return AttendanceDto(
      attendanceId: data['attendanceId'] as String? ?? doc.id,
      eventId: data['eventId'] as String,
      studentId: data['studentId'] as String,
      checkInTime: (data['checkInTime'] as fs.Timestamp?)?.toDate(),
      checkInGeo: _toGeoPoint(data['checkInGeo'] as fs.GeoPoint?),
      checkOutTime: (data['checkOutTime'] as fs.Timestamp?)?.toDate(),
      checkOutGeo: _toGeoPoint(data['checkOutGeo'] as fs.GeoPoint?),
      workingHours: (data['workingHours'] as num?)?.toDouble(),
      accrued: data['accrued'] as bool? ?? false,
      createdAt: (data['createdAt'] as fs.Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as fs.Timestamp).toDate(),
    );
  }

  /// Builds a DTO from a pure domain [AttendanceRecord] (outbound mapping).
  factory AttendanceDto.fromEntity(AttendanceRecord record) {
    return AttendanceDto(
      attendanceId: record.attendanceId,
      eventId: record.eventId,
      studentId: record.studentId,
      checkInTime: record.checkInTime,
      checkInGeo: record.checkInGeo,
      checkOutTime: record.checkOutTime,
      checkOutGeo: record.checkOutGeo,
      workingHours: record.workingHours,
      accrued: record.accrued,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  /// Serialises this DTO to a Firestore-ready map.
  ///
  /// Optional fields are written only when present so an absent check-out or
  /// geo leaves no key in the document. The `accrued` field is intentionally
  /// **never** written: it is owned exclusively by the trusted backend
  /// earnings service, and emitting it here would let a client create or
  /// overwrite it (R11.1, R11.2).
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'attendanceId': attendanceId,
      'eventId': eventId,
      'studentId': studentId,
      if (checkInTime != null) 'checkInTime': fs.Timestamp.fromDate(checkInTime!),
      if (checkInGeo != null) 'checkInGeo': _fromGeoPoint(checkInGeo!),
      if (checkOutTime != null)
        'checkOutTime': fs.Timestamp.fromDate(checkOutTime!),
      if (checkOutGeo != null) 'checkOutGeo': _fromGeoPoint(checkOutGeo!),
      if (workingHours != null) 'workingHours': workingHours,
      'createdAt': fs.Timestamp.fromDate(createdAt),
      'updatedAt': fs.Timestamp.fromDate(updatedAt),
    };
  }

  /// Converts this DTO to a pure domain [AttendanceRecord] (inbound mapping).
  AttendanceRecord toEntity() {
    return AttendanceRecord(
      attendanceId: attendanceId,
      eventId: eventId,
      studentId: studentId,
      checkInTime: checkInTime,
      checkInGeo: checkInGeo,
      checkOutTime: checkOutTime,
      checkOutGeo: checkOutGeo,
      workingHours: workingHours,
      accrued: accrued,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Converts Firestore's [fs.GeoPoint] to the backend-neutral [GeoPoint], or
  /// `null` when absent.
  static GeoPoint? _toGeoPoint(fs.GeoPoint? geo) {
    if (geo == null) {
      return null;
    }
    return GeoPoint(latitude: geo.latitude, longitude: geo.longitude);
  }

  /// Converts the backend-neutral [GeoPoint] to Firestore's [fs.GeoPoint].
  static fs.GeoPoint _fromGeoPoint(GeoPoint geo) =>
      fs.GeoPoint(geo.latitude, geo.longitude);
}
