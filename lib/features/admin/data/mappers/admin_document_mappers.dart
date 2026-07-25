import 'package:cloud_firestore/cloud_firestore.dart' as fb;

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../../core/value_objects/geo_point.dart';
import '../../../../core/value_objects/money.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/entities/event_location.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../../reports/domain/entities/report.dart';

/// Inline Firestore document mappers for the Admin read surface (R6.4–R6.6,
/// R6.8).
///
/// The Admin lists are read-only projections over other features' collections
/// (`students`, `vendors`, `events`, `reports`). Rather than depend on those
/// features' DTOs — which keeps this repository self-contained and avoids
/// cross-feature coupling for a read-only view — these helpers convert a raw
/// Firestore [fb.DocumentSnapshot] into the corresponding pure domain entity.
///
/// All Firebase types (`Timestamp`, `GeoPoint`) are confined to this file; the
/// returned entities use only plain Dart values and the project's value
/// objects, so no backend type ever crosses the domain boundary.
class AdminDocumentMappers {
  const AdminDocumentMappers._();

  /// Maps a `students/{uid}` document to a [Student] entity (R6.4).
  static Student studentFromDoc(
    fb.DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = _requireData(doc);
    return Student(
      uid: (data['uid'] as String?) ?? doc.id,
      fullName: data['fullName'] as String,
      phone: PhoneNumber.parse(data['phone'] as String),
      gender: GenderX.parse(data['gender'] as String),
      dateOfBirth: _dateTime(data['dateOfBirth']),
      city: data['city'] as String,
      heightCm: (data['heightCm'] as num).toInt(),
      profilePhotoPath: data['profilePhotoPath'] as String,
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  /// Maps a `vendors/{uid}` document to a [Vendor] entity (R6.5).
  static Vendor vendorFromDoc(
    fb.DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = _requireData(doc);
    return Vendor(
      uid: (data['uid'] as String?) ?? doc.id,
      fullName: data['fullName'] as String,
      agencyName: data['agencyName'] as String,
      phone: PhoneNumber.parse(data['phone'] as String),
      city: data['city'] as String,
      address: data['address'] as String,
      approvalStatus: ApprovalStatusX.parse(data['approvalStatus'] as String),
      aadhaarOrPan: data['aadhaarOrPan'] as String?,
      website: data['website'] as String?,
      socialLinks: _stringList(data['socialLinks']),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
    );
  }

  /// Maps an `events/{eventId}` document to an [Event] entity (R6.6).
  static Event eventFromDoc(
    fb.DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = _requireData(doc);
    final location = data['location'] as Map<String, Object?>;
    final geo = location['geo'] as fb.GeoPoint;
    return Event(
      eventId: (data['eventId'] as String?) ?? doc.id,
      vendorId: data['vendorId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      date: _dateTime(data['date']),
      startTime: _dateTime(data['startTime']),
      endTime: _dateTime(data['endTime']),
      location: EventLocation(
        label: location['label'] as String,
        geo: GeoPoint(
          latitude: geo.latitude,
          longitude: geo.longitude,
        ),
      ),
      slots: (data['slots'] as num).toInt(),
      // `payPerHead` is persisted as integer minor units (paise) by the events
      // EventDto; read it the same way here (reading it as major units inflated
      // the amount 100×).
      payPerHead: Money.fromMinorUnits(
        (data['payPerHead'] as num).toInt(),
        requirePayPerHeadRange: false,
      ),
      status: EventStatusX.parse(data['status'] as String),
      approvalStatus: ApprovalStatusX.parse(
        (data['approvalStatus'] as String?) ?? 'Approved',
      ),
      startCode: data['startCode'] as String?,
      endCode: data['endCode'] as String?,
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
      platformCommissionPercent:
          (data['platformCommissionPercent'] as num?)?.toInt() ?? 10,
    );
  }

  /// Maps a `reports/{reportId}` document to a [Report] entity (R6.8).
  static Report reportFromDoc(
    fb.DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = _requireData(doc);
    return Report(
      reportId: (data['reportId'] as String?) ?? doc.id,
      submitterId: data['submitterId'] as String,
      submitterRole: SubmitterRoleX.parse(data['submitterRole'] as String),
      category: ReportCategoryX.parse(data['category'] as String),
      description: data['description'] as String,
      createdAt: _dateTime(data['createdAt']),
    );
  }

  static Map<String, Object?> _requireData(
    fb.DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Document ${doc.id} has no data');
    }
    return data;
  }

  static DateTime _dateTime(Object? value) {
    if (value is fb.Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    throw StateError('Expected a Timestamp but got ${value.runtimeType}');
  }

  static List<String> _stringList(Object? value) {
    if (value == null) {
      return const <String>[];
    }
    return (value as List<Object?>).cast<String>();
  }
}
