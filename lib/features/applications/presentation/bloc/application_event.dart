import 'package:equatable/equatable.dart';

import '../../../events/domain/repositories/event_repository.dart';
import '../../domain/usecases/decide_application.dart';

/// Base type for every event handled by the `ApplicationBloc`.
///
/// The bloc serves both sides of the application lifecycle: a student applying
/// to an event ([ApplyRequested]) and a vendor reviewing applicants
/// ([ApplicationsWatchStarted], [DecideRequested]) and generating attendance
/// codes ([AttendanceCodeRequested]).
sealed class ApplicationEvent extends Equatable {
  const ApplicationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// A student requests to apply to the event identified by [eventId].
///
/// The applying [studentId] is supplied by the caller (resolved from the
/// authenticated session) so the bloc stays free of any session dependency.
/// Maps to [Applying] then [Applied] on success, [DuplicateApplication] when
/// the student already applied (R9.2), or [ApplicationFailure] otherwise.
class ApplyRequested extends ApplicationEvent {
  const ApplyRequested({required this.studentId, required this.eventId});

  /// The id of the applying student.
  final String studentId;

  /// The id of the event being applied to.
  final String eventId;

  @override
  List<Object?> get props => <Object?>[studentId, eventId];
}

/// A vendor decides ([approve]/[reject]) the application identified by
/// [applicationId] for an event the vendor owns (R5.4, R5.5, R9.3, R9.4).
///
/// The deciding [vendorId] is supplied by the caller. The use case enforces
/// ownership (R5.9) and the Pending-only guard (R5.8, R9.5); a denied action
/// surfaces as [ApplicationFailure].
class DecideRequested extends ApplicationEvent {
  const DecideRequested({
    required this.vendorId,
    required this.applicationId,
    required this.decision,
  });

  /// The id of the vendor making the decision.
  final String vendorId;

  /// The composite id of the application being decided.
  final String applicationId;

  /// Whether to approve or reject the application.
  final ApplicationDecision decision;

  @override
  List<Object?> get props => <Object?>[vendorId, applicationId, decision];
}

/// Starts watching the applications submitted to the event identified by
/// [eventId] for the vendor's applicant list (R5.3).
///
/// Emits a fresh [ApplicationsLoaded] whenever the underlying list changes
/// (an empty list when no applications exist).
class ApplicationsWatchStarted extends ApplicationEvent {
  const ApplicationsWatchStarted({required this.eventId});

  /// The id of the event whose applications are observed.
  final String eventId;

  @override
  List<Object?> get props => <Object?>[eventId];
}

/// A vendor requests an attendance code ([EventCodeKind.start] or
/// [EventCodeKind.end]) for an event the vendor owns (R5.6).
///
/// Ownership is enforced by the use case (R5.9); a non-owner action surfaces
/// as [ApplicationFailure].
class AttendanceCodeRequested extends ApplicationEvent {
  const AttendanceCodeRequested({
    required this.vendorId,
    required this.eventId,
    required this.kind,
  });

  /// The id of the vendor requesting the code.
  final String vendorId;

  /// The id of the event the code is generated for.
  final String eventId;

  /// Whether to generate the start (check-in) or end (check-out) code.
  final EventCodeKind kind;

  @override
  List<Object?> get props => <Object?>[vendorId, eventId, kind];
}
