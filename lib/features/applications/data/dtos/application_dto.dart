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
  });

  /// The composite document id `"{eventId}_{studentId}"`.
  final String applicationId;

  /// The id of the event being applied to.
  final String eventId;

  /// The id of the applying student.
  final String studentId;

  /// The wire/storage status string: `"Pending" | "Approved" | "Rejected"`.
  final String status;

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
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
