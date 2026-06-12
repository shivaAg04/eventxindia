import '../entities/event.dart';
import '../repositories/event_repository.dart';

/// Streams every [Event] currently in the active state for student discovery
/// and the student dashboard (R4.1, R8.1, R8.2).
///
/// All active events are emitted regardless of remaining slots (R8.1). The
/// stream re-emits whenever the underlying active set changes; an empty list
/// signals that no active events are available, which the presentation layer
/// renders as an empty-state indication (R8.2).
class WatchActiveEvents {
  const WatchActiveEvents({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

  /// Returns the stream of active events.
  Stream<List<Event>> call() => _repository.watchActive();
}
