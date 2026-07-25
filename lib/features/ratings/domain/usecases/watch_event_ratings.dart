import '../entities/rating_entry.dart';
import '../repositories/rating_repository.dart';

/// Streams every rating recorded for an event, backing the vendor's rate view
/// (to lock already-rated students) and the admin's event-level view (R rating).
class WatchEventRatings {
  const WatchEventRatings({required RatingRepository repository})
      : _repository = repository;

  final RatingRepository _repository;

  Stream<List<RatingEntry>> call(String eventId) =>
      _repository.watchByEvent(eventId);
}
