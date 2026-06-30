import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../entities/application.dart';
import '../repositories/application_repository.dart';

/// The decision a vendor makes on a pending application: approve or reject.
///
/// [DecideApplication] maps this to the resulting [ApplicationStatus]
/// ([approve] → [ApplicationStatus.approved], [reject] →
/// [ApplicationStatus.rejected]) (R5.4, R5.5, R9.3, R9.4).
enum ApplicationDecision {
  /// Approve the application, moving it to [ApplicationStatus.approved].
  approve,

  /// Reject the application, moving it to [ApplicationStatus.rejected].
  reject;

  /// The [ApplicationStatus] this decision transitions the application to.
  ApplicationStatus get targetStatus => switch (this) {
        ApplicationDecision.approve => ApplicationStatus.approved,
        ApplicationDecision.reject => ApplicationStatus.rejected,
      };
}

/// Approves or rejects a student's application on behalf of the owning vendor
/// (R5.4, R5.5, R5.8, R5.9, R9.3, R9.4, R9.5).
///
/// The flow is a railway of guards:
///
/// 1. Load the application. A missing application short-circuits with the
///    repository's failure (typically a [NotFoundFailure]).
/// 2. Load the application's event and verify the deciding [vendorId] owns it
///    (`event.vendorId == vendorId`); otherwise the action is denied with an
///    [AuthorizationFailure] (R5.9).
/// 3. The application must be in [ApplicationStatus.pending]; otherwise the
///    action is rejected with a [StateTransitionFailure] and the application
///    is left unchanged (R5.8, R9.5).
/// 4. The application is transitioned to the decision's target status and
///    persisted via [ApplicationRepository.decide] (R5.4, R5.5, R9.3, R9.4).
///
/// This is pure domain logic: it depends only on the repository abstractions
/// and a [now] clock, never on any backend type.
class DecideApplication {
  /// Creates the use case with its injected [ApplicationRepository],
  /// [EventRepository], and a [now] clock used to timestamp the decision.
  const DecideApplication({
    required ApplicationRepository applicationRepository,
    required EventRepository eventRepository,
    required DateTime Function() now,
  })  : _applicationRepository = applicationRepository,
        _eventRepository = eventRepository,
        _now = now;

  final ApplicationRepository _applicationRepository;
  final EventRepository _eventRepository;
  final DateTime Function() _now;

  /// Applies [decision] to the application identified by [applicationId] on
  /// behalf of [vendorId].
  ///
  /// Returns the updated [Application] on success, or a [Failure] when the
  /// application or its event does not exist, the vendor does not own the
  /// event (R5.9), or the application is not [ApplicationStatus.pending]
  /// (R5.8, R9.5).
  Future<Result<Application, Failure>> call({
    required String vendorId,
    required String applicationId,
    required ApplicationDecision decision,
  }) async {
    final Result<Application, Failure> applicationResult =
        await _applicationRepository.getById(applicationId);

    final Application? application = applicationResult.valueOrNull;
    if (application == null) {
      return Result<Application, Failure>.err(
        applicationResult.failureOrNull ?? const NotFoundFailure(),
      );
    }

    final Result<Event, Failure> eventResult =
        await _eventRepository.getById(application.eventId);

    final Event? event = eventResult.valueOrNull;
    if (event == null) {
      return Result<Application, Failure>.err(
        eventResult.failureOrNull ?? const NotFoundFailure(),
      );
    }

    if (event.vendorId != vendorId) {
      return const Result<Application, Failure>.err(
        AuthorizationFailure(
          message: 'You are not authorized to decide applications for this '
              'event.',
        ),
      );
    }

    if (application.status != ApplicationStatus.pending) {
      return const Result<Application, Failure>.err(
        StateTransitionFailure(
          message: 'The application is not in a Pending state.',
        ),
      );
    }

    // Approving a full event is rejected: an event cannot have more approved
    // applicants than it has slots (capacity guard).
    if (decision == ApplicationDecision.approve && event.isFull) {
      return const Result<Application, Failure>.err(
        StateTransitionFailure(
          message: 'This event is full — all slots have been filled.',
        ),
      );
    }

    final Application decided = application.copyWith(
      status: decision.targetStatus,
      updatedAt: _now(),
    );

    final Result<Application, Failure> result =
        await _applicationRepository.decide(decided);

    // On a successful approval, bump the event's approved count so remaining
    // seats stay current and the capacity guard holds for later approvals.
    // Best-effort: a failed counter write does not undo the decision.
    if (decision == ApplicationDecision.approve && result.isOk) {
      await _eventRepository.setApprovedCount(
        event.eventId,
        event.approvedCount + 1,
      );
    }

    return result;
  }
}
