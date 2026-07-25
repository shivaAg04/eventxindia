import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/approval_status.dart';
import '../entities/event.dart';
import '../repositories/event_repository.dart';

/// Admin moderation of an event's publish gate.
///
/// An event is created [ApprovalStatus.pending] and stays out of student
/// discovery until an admin approves it (see `CreateEvent`). This use case is
/// the admin-only action that moves an event to [ApprovalStatus.approved]
/// (publishes it) or [ApprovalStatus.rejected] (keeps it hidden).
///
/// Setting the status back to [ApprovalStatus.pending] is rejected with a
/// [ValidationFailure]: moderation only ever moves *out* of pending. Persisting
/// goes through [EventRepository.setApprovalStatus]. Authorization that the
/// caller is actually an admin is enforced server-side by the Firestore rules
/// (only an admin may write `approvalStatus`); this use case models the intent.
///
/// Depends only on the abstract [EventRepository], so it is unaffected by the
/// choice of backend.
class SetEventApproval {
  const SetEventApproval({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

  /// Sets the moderation [status] on the event identified by [eventId].
  Future<Result<Event, Failure>> call({
    required String eventId,
    required ApprovalStatus status,
  }) {
    if (status == ApprovalStatus.pending) {
      return Future<Result<Event, Failure>>.value(
        const Result<Event, Failure>.err(
          ValidationFailure(
            fieldErrors: <FieldError>[
              FieldError(
                field: 'approvalStatus',
                message: 'Moderation can only approve or reject an event.',
              ),
            ],
          ),
        ),
      );
    }
    return _repository.setApprovalStatus(eventId, status);
  }
}
