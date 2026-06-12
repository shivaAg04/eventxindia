import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/event.dart';
import '../repositories/event_repository.dart';

/// Fetches a single [Event] by id for the event-detail view (R8.5).
///
/// Returns the event on success, or a [NotFoundFailure] when no event with the
/// given id exists. The presentation layer renders the event's title,
/// description, date, times, location, slots, and pay-per-head (R8.5).
class GetEvent {
  const GetEvent({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

  /// Returns the event identified by [eventId], or a [Failure].
  Future<Result<Event, Failure>> call(String eventId) =>
      _repository.getById(eventId);
}
