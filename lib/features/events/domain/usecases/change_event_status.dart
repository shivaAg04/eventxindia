import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/event_status.dart';
import '../entities/event.dart';
import '../event_ownership.dart';
import '../repositories/event_repository.dart';

/// Changes the status of an [Event] on behalf of a vendor (R5.9, R7.5).
///
/// The flow is:
/// 1. The requested [status] must be one of [EventStatus.active],
///    [EventStatus.closed], or [EventStatus.completed]. Because [EventStatus]
///    is a closed enum, an unknown value can never reach this use case; the
///    boundary parser [EventStatusX.parse] rejects unknown strings with an
///    error before they become an [EventStatus] (R7.5). This use case accepts
///    any valid enum value.
/// 2. Fetch the event by [eventId]; a missing event yields a [NotFoundFailure].
/// 3. Authorize: the vendor identified by [vendorId] must own the event,
///    otherwise the use case rejects with an [AuthorizationFailure] and the
///    status is left unchanged (R5.9).
/// 4. Persist the new status via [EventRepository.updateStatus] (R7.5).
///
/// This use case depends only on the abstract [EventRepository], so it is
/// unaffected by the choice of backend.
class ChangeEventStatus {
  const ChangeEventStatus({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

  /// Authorizes ownership, then transitions the event to [status].
  Future<Result<Event, Failure>> call({
    required String vendorId,
    required String eventId,
    required EventStatus status,
  }) async {
    final Result<Event, Failure> fetched = await _repository.getById(eventId);

    return fetched.fold(
      (Event event) {
        if (!ownsEvent(vendorId, event)) {
          return Future<Result<Event, Failure>>.value(
            const Result<Event, Failure>.err(
              AuthorizationFailure(
                message: 'You are not authorized to change this event.',
              ),
            ),
          );
        }
        return _repository.updateStatus(eventId, status);
      },
      (Failure failure) => Future<Result<Event, Failure>>.value(
        Result<Event, Failure>.err(failure),
      ),
    );
  }
}
