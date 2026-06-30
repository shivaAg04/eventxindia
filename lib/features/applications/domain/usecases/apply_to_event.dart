import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../entities/application.dart';
import '../repositories/application_repository.dart';

/// Submits a student's application to an event (R8.6, R8.7, R9.1, R9.2, R9.6).
///
/// The flow is a railway of guards:
///
/// 1. Load the target event. A missing event short-circuits with the
///    repository's failure (typically a [NotFoundFailure]).
/// 2. The event must be [EventStatus.active]; otherwise the application is
///    rejected with a [StateTransitionFailure] and **no record is created**
///    (R8.7).
/// 3. A new [Application] is built in [ApplicationStatus.pending] (R9.1) under
///    the composite id `"{eventId}_{studentId}"` (R9.6) and handed to
///    [ApplicationRepository.create]. The repository honours the composite id
///    as a dedupe key, so a second application for the same event by the same
///    student is rejected with the existing record left unchanged (R9.2).
///
/// This is pure domain logic: it depends only on the repository abstractions
/// and a [now] clock, never on any backend type, so it is unaffected by a
/// future change of backend.
class ApplyToEvent {
  /// Creates the use case with its injected [EventRepository],
  /// [ApplicationRepository], and a [now] clock used to timestamp the new
  /// application.
  const ApplyToEvent({
    required EventRepository eventRepository,
    required ApplicationRepository applicationRepository,
    required ProfileRepository profileRepository,
    required DateTime Function() now,
  })  : _eventRepository = eventRepository,
        _applicationRepository = applicationRepository,
        _profileRepository = profileRepository,
        _now = now;

  final EventRepository _eventRepository;
  final ApplicationRepository _applicationRepository;
  final ProfileRepository _profileRepository;
  final DateTime Function() _now;

  /// Applies [studentId] to the event identified by [eventId].
  ///
  /// Returns the persisted [Application] on success, or a [Failure] when the
  /// event does not exist, is not [EventStatus.active] (R8.7), or a duplicate
  /// application already exists (R9.2).
  Future<Result<Application, Failure>> call({
    required String studentId,
    required String eventId,
  }) async {
    final Result<Event, Failure> eventResult =
        await _eventRepository.getById(eventId);

    final Event? event = eventResult.valueOrNull;
    if (event == null) {
      return Result<Application, Failure>.err(
        eventResult.failureOrNull ?? const NotFoundFailure(),
      );
    }

    if (event.status != EventStatus.active) {
      return const Result<Application, Failure>.err(
        StateTransitionFailure(
          message: 'This event is no longer available for applications.',
        ),
      );
    }

    // Snapshot the applying student's profile onto the application so the owning
    // vendor can identify the candidate from the application alone, without
    // being granted read access to the student's private profile document. A
    // profile read failure must not block applying, so the snapshot is
    // best-effort (the fields stay null).
    final Student? student =
        (await _profileRepository.getStudent(studentId)).valueOrNull;

    final Application application = Application.create(
      eventId: eventId,
      studentId: studentId,
      now: _now(),
      applicantName: student?.fullName,
      applicantPhone: student?.phone.e164,
      applicantCity: student?.city,
      eventTitle: event.title,
      eventLocation: event.location.label,
      eventPayMinorUnits: event.payPerHead.minorUnits,
      eventDate: event.date,
    );

    return _applicationRepository.create(application);
  }
}
