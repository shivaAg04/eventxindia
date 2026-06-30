import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore wire/document shape for an application document.
///
/// This DTO is the only place that knows about Firebase types (`Timestamp`,
/// `DocumentSnapshot`). It is built from a Firestore document on the inbound
/// path and serialised back to a `Map<String, dynamic>` on the outbound path.
/// The conversion to/from the pure domain [Application] entity lives in
/// `ApplicationMapper`, keeping this type a thin data carrier.
///
/// Documents are stored under the composite id `"{eventId}_{studentId}"`
/// (R9.6); [applicationId] mirrors that id inside the document.
class ApplicationDto {
  const ApplicationDto({
    required this.applicationId,
    required this.eventId,
    required this.studentId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.applicantName,
    this.applicantPhone,
    this.applicantCity,
    this.eventTitle,
    this.eventLocation,
    this.eventPayMinorUnits,
    this.eventDate,
  });

  /// The composite document id `"{eventId}_{studentId}"`.
  final String applicationId;

  /// The id of the event being applied to.
  final String eventId;

  /// The id of the applying student.
  final String studentId;

  /// The wire/storage status string: `"Pending" | "Approved" | "Rejected"`.
  final String status;

  /// Snapshot of the applying student's name/phone/city at apply time, so the
  /// owning vendor can identify the candidate without reading the student's
  /// private profile. `null` on records created before this was introduced.
  final String? applicantName;
  final String? applicantPhone;
  final String? applicantCity;

  /// Snapshot of the event's display fields at apply time, so the student's
  /// applied/approved lists render the event by name without a second read.
  final String? eventTitle;
  final String? eventLocation;
  final int? eventPayMinorUnits;
  final Timestamp? eventDate;

  /// Creation timestamp in Firestore-native form.
  final Timestamp createdAt;

  /// Last-update timestamp in Firestore-native form.
  final Timestamp updatedAt;

  /// Builds a DTO from a Firestore [doc].
  ///
  /// Falls back to the document id for [applicationId] when the stored field is
  /// absent, so a record written without the redundant field still round-trips.
  factory ApplicationDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return ApplicationDto(
      applicationId: (data['applicationId'] as String?) ?? doc.id,
      eventId: data['eventId'] as String,
      studentId: data['studentId'] as String,
      status: data['status'] as String,
      applicantName: data['applicantName'] as String?,
      applicantPhone: data['applicantPhone'] as String?,
      applicantCity: data['applicantCity'] as String?,
      eventTitle: data['eventTitle'] as String?,
      eventLocation: data['eventLocation'] as String?,
      eventPayMinorUnits: (data['eventPayMinorUnits'] as num?)?.toInt(),
      eventDate: data['eventDate'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp,
      updatedAt: data['updatedAt'] as Timestamp,
    );
  }

  /// Serialises this DTO into a Firestore document payload.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'applicationId': applicationId,
        'eventId': eventId,
        'studentId': studentId,
        'status': status,
        if (applicantName != null) 'applicantName': applicantName,
        if (applicantPhone != null) 'applicantPhone': applicantPhone,
        if (applicantCity != null) 'applicantCity': applicantCity,
        if (eventTitle != null) 'eventTitle': eventTitle,
        if (eventLocation != null) 'eventLocation': eventLocation,
        if (eventPayMinorUnits != null) 'eventPayMinorUnits': eventPayMinorUnits,
        if (eventDate != null) 'eventDate': eventDate,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
