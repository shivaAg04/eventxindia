import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../../core/value_objects/geo_point.dart';
import '../../../../core/value_objects/money.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_location.dart';

/// Firebase data-transfer object for an `events/{eventId}` document.
///
/// This is the only place Firebase types (`DocumentSnapshot`, `Timestamp`,
/// `GeoPoint`) touch the [Event] shape. The DTO parses a Firestore document
/// into plain Dart fields ([fromFirestore]), serialises back to a
/// Firestore-ready map ([toFirestore]), and converts to/from the pure domain
/// [Event] entity ([toEntity]/[EventDto.fromEntity]) — mapping:
///
/// - Firestore `Timestamp` ↔ [DateTime] for `date`, `startTime`, `endTime`,
///   `createdAt`, `updatedAt`;
/// - Firestore `GeoPoint` ↔ the backend-neutral [GeoPoint] value object inside
///   the `location` map (`{label, geo}`);
/// - the integer minor-units `payPerHead` ↔ the fixed-precision [Money] value
///   object (stored as exact paise to avoid floating-point drift, per the
///   design Data Models note);
/// - the `status` wire-name (`Active`/`Closed`/`Completed`) ↔ [EventStatus].
///
/// Optional attendance codes (`startCode`, `endCode`) are persisted only when
/// present so an event with no generated codes leaves no key in the document.
class EventDto {
  const EventDto({
    required this.eventId,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.locationLabel,
    required this.locationGeo,
    required this.slots,
    required this.payPerHeadMinorUnits,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.startCode,
    this.endCode,
    this.approvedCount = 0,
    this.platformCommissionPercent = 10,
    this.approvalStatus = 'Approved',
  });

  /// The unique identifier of the event (matches the document id).
  final String eventId;

  /// The id of the owning vendor.
  final String vendorId;

  /// The event title.
  final String title;

  /// The event description.
  final String description;

  /// The calendar date on which the event takes place.
  final DateTime date;

  /// The scheduled start time of the event.
  final DateTime startTime;

  /// The scheduled end time of the event.
  final DateTime endTime;

  /// The human-readable location label.
  final String locationLabel;

  /// The location's geographic coordinate (Firebase `GeoPoint`).
  final fs.GeoPoint locationGeo;

  /// The number of student slots available.
  final int slots;

  /// The pay-per-head amount expressed in exact minor units (paise).
  final int payPerHeadMinorUnits;

  /// The event status wire-name (`Active` | `Closed` | `Completed`).
  final String status;

  /// The admin moderation wire-name (`Pending` | `Approved` | `Rejected`);
  /// defaults to `Approved` for documents written before this gate existed.
  final String approvalStatus;

  /// The number of approved applicants; defaults to 0 for documents written
  /// before this field existed.
  final int approvedCount;

  /// The platform commission percentage snapshotted at creation; defaults to 10
  /// for documents written before this field existed.
  final int platformCommissionPercent;

  /// The attendance check-in code, or `null` until generated.
  final String? startCode;

  /// The attendance check-out code, or `null` until generated.
  final String? endCode;

  /// When the event was created.
  final DateTime createdAt;

  /// When the event was last updated.
  final DateTime updatedAt;

  /// Parses a Firestore `events/{eventId}` document into an [EventDto].
  factory EventDto.fromFirestore(fs.DocumentSnapshot<Object?> doc) {
    final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    final Map<String, dynamic> location =
        (data['location'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return EventDto(
      eventId: data['eventId'] as String? ?? doc.id,
      vendorId: data['vendorId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      date: (data['date'] as fs.Timestamp).toDate(),
      startTime: (data['startTime'] as fs.Timestamp).toDate(),
      endTime: (data['endTime'] as fs.Timestamp).toDate(),
      locationLabel: location['label'] as String,
      locationGeo: location['geo'] as fs.GeoPoint,
      slots: (data['slots'] as num).toInt(),
      payPerHeadMinorUnits: (data['payPerHead'] as num).toInt(),
      status: data['status'] as String,
      approvalStatus: data['approvalStatus'] as String? ?? 'Approved',
      approvedCount: (data['approvedCount'] as num?)?.toInt() ?? 0,
      platformCommissionPercent:
          (data['platformCommissionPercent'] as num?)?.toInt() ?? 10,
      startCode: data['startCode'] as String?,
      endCode: data['endCode'] as String?,
      createdAt: (data['createdAt'] as fs.Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as fs.Timestamp).toDate(),
    );
  }

  /// Builds a DTO from a pure domain [Event] entity (outbound mapping).
  factory EventDto.fromEntity(Event event) {
    return EventDto(
      eventId: event.eventId,
      vendorId: event.vendorId,
      title: event.title,
      description: event.description,
      date: event.date,
      startTime: event.startTime,
      endTime: event.endTime,
      locationLabel: event.location.label,
      locationGeo: fs.GeoPoint(
        event.location.geo.latitude,
        event.location.geo.longitude,
      ),
      slots: event.slots,
      payPerHeadMinorUnits: event.payPerHead.minorUnits,
      status: event.status.wireName,
      approvalStatus: event.approvalStatus.wireName,
      approvedCount: event.approvedCount,
      platformCommissionPercent: event.platformCommissionPercent,
      startCode: event.startCode,
      endCode: event.endCode,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }

  /// Serialises this DTO to a Firestore-ready map (Firebase `Timestamp`s and
  /// `GeoPoint`s).
  ///
  /// Optional attendance codes are written only when present so absent codes
  /// leave no key in the document.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'eventId': eventId,
      'vendorId': vendorId,
      'title': title,
      'description': description,
      'date': fs.Timestamp.fromDate(date),
      'startTime': fs.Timestamp.fromDate(startTime),
      'endTime': fs.Timestamp.fromDate(endTime),
      'location': <String, dynamic>{
        'label': locationLabel,
        'geo': locationGeo,
      },
      'slots': slots,
      'payPerHead': payPerHeadMinorUnits,
      'status': status,
      'approvalStatus': approvalStatus,
      'approvedCount': approvedCount,
      'platformCommissionPercent': platformCommissionPercent,
      if (startCode != null) 'startCode': startCode,
      if (endCode != null) 'endCode': endCode,
      'createdAt': fs.Timestamp.fromDate(createdAt),
      'updatedAt': fs.Timestamp.fromDate(updatedAt),
    };
  }

  /// Converts this DTO to a pure domain [Event] entity (inbound mapping).
  Event toEntity() {
    return Event(
      eventId: eventId,
      vendorId: vendorId,
      title: title,
      description: description,
      date: date,
      startTime: startTime,
      endTime: endTime,
      location: EventLocation(
        label: locationLabel,
        geo: GeoPoint(
          latitude: locationGeo.latitude,
          longitude: locationGeo.longitude,
        ),
      ),
      slots: slots,
      payPerHead: Money.fromMinorUnits(payPerHeadMinorUnits),
      status: EventStatusX.parse(status),
      approvalStatus: ApprovalStatusX.parse(approvalStatus),
      approvedCount: approvedCount,
      platformCommissionPercent: platformCommissionPercent,
      startCode: startCode,
      endCode: endCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
