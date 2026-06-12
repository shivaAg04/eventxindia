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
  });

  /// Creates a brand-new application for [studentId] against [eventId].
  ///
  /// The [applicationId] is derived as the composite key
  /// `"{eventId}_{studentId}"` and the [status] is set to
  /// [ApplicationStatus.pending] per R9.1. The [createdAt] and [updatedAt]
  /// timestamps are both initialised to [now].
  factory Application.create({
    required String eventId,
    required String studentId,
    required DateTime now,
  }) {
    return Application(
      applicationId: buildId(eventId: eventId, studentId: studentId),
      eventId: eventId,
      studentId: studentId,
      status: ApplicationStatus.pending,
      createdAt: now,
      updatedAt: now,
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
  }) {
    return Application(
      applicationId: applicationId,
      eventId: eventId,
      studentId: studentId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
