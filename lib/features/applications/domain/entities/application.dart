import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/application_status.dart';

/// A student's application to work an event.
///
/// An application is uniquely identified by the composite [applicationId]
/// `"{eventId}_{studentId}"`, which doubles as the dedupe key that prevents a
/// student from applying to the same event more than once (R9.2). A newly
/// created application starts in [ApplicationStatus.pending] (R9.1) and may
/// later transition to approved or rejected by the owning vendor.
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only, so it is unaffected by a future change of backend.
class Application extends Equatable {
  const Application({
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

  /// Creates a brand-new application for [studentId] against [eventId].
  ///
  /// The [applicationId] is derived as the composite key
  /// `"{eventId}_{studentId}"` and the [status] is set to
  /// [ApplicationStatus.pending] per R9.1. The [createdAt] and [updatedAt]
  /// timestamps are both initialised to [now].
  ///
  /// The optional [applicantName]/[applicantPhone]/[applicantCity] are a
  /// snapshot of the applying student's profile taken at apply time, so the
  /// owning vendor can identify the candidate from the application alone
  /// without reading the student's private profile document.
  factory Application.create({
    required String eventId,
    required String studentId,
    required DateTime now,
    String? applicantName,
    String? applicantPhone,
    String? applicantCity,
    String? eventTitle,
    String? eventLocation,
    int? eventPayMinorUnits,
    DateTime? eventDate,
  }) {
    return Application(
      applicationId: buildId(eventId: eventId, studentId: studentId),
      eventId: eventId,
      studentId: studentId,
      status: ApplicationStatus.pending,
      createdAt: now,
      updatedAt: now,
      applicantName: applicantName,
      applicantPhone: applicantPhone,
      applicantCity: applicantCity,
      eventTitle: eventTitle,
      eventLocation: eventLocation,
      eventPayMinorUnits: eventPayMinorUnits,
      eventDate: eventDate,
    );
  }

  /// The composite identifier `"{eventId}_{studentId}"`.
  ///
  /// This is the document id used for persistence and the natural dedupe key
  /// for "at most one application per student per event" (R9.2).
  final String applicationId;

  /// The id of the event being applied to.
  final String eventId;

  /// The id of the applying student.
  final String studentId;

  /// The current review status of the application.
  final ApplicationStatus status;

  /// The applying student's full name at apply time; `null` for records created
  /// before this snapshot was introduced.
  final String? applicantName;

  /// The applying student's phone (E.164) at apply time; `null` when unknown.
  final String? applicantPhone;

  /// The applying student's city at apply time; `null` when unknown.
  final String? applicantCity;

  /// Snapshot of the event's display fields at apply time, so the student's
  /// applied/approved lists can show the event by name and detail without a
  /// second read. `null` on records created before this was introduced.
  final String? eventTitle;
  final String? eventLocation;
  final int? eventPayMinorUnits;
  final DateTime? eventDate;

  /// When the application was created.
  final DateTime createdAt;

  /// When the application was last updated.
  final DateTime updatedAt;

  /// Builds the composite application id from [eventId] and [studentId].
  static String buildId({
    required String eventId,
    required String studentId,
  }) =>
      '${eventId}_$studentId';

  /// Returns a copy of this application with the given fields replaced.
  Application copyWith({
    ApplicationStatus? status,
    DateTime? updatedAt,
    String? applicantName,
    String? applicantPhone,
    String? applicantCity,
    String? eventTitle,
    String? eventLocation,
    int? eventPayMinorUnits,
    DateTime? eventDate,
  }) {
    return Application(
      applicationId: applicationId,
      eventId: eventId,
      studentId: studentId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      applicantName: applicantName ?? this.applicantName,
      applicantPhone: applicantPhone ?? this.applicantPhone,
      applicantCity: applicantCity ?? this.applicantCity,
      eventTitle: eventTitle ?? this.eventTitle,
      eventLocation: eventLocation ?? this.eventLocation,
      eventPayMinorUnits: eventPayMinorUnits ?? this.eventPayMinorUnits,
      eventDate: eventDate ?? this.eventDate,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        applicationId,
        eventId,
        studentId,
        status,
        createdAt,
        updatedAt,
        applicantName,
        applicantPhone,
        applicantCity,
        eventTitle,
        eventLocation,
        eventPayMinorUnits,
        eventDate,
      ];

  @override
  String toString() => 'Application('
      'applicationId: $applicationId, '
      'eventId: $eventId, '
      'studentId: $studentId, '
      'status: $status, '
      'createdAt: $createdAt, '
      'updatedAt: $updatedAt)';
}
