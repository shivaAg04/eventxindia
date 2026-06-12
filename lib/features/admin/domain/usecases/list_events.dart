import '../../../events/domain/entities/event.dart';
import '../repositories/admin_repository.dart';

/// Streams all events, each with its status, for the Admin event list
/// (R6.6, R6.9).
///
/// Delegates to [AdminRepository.listEvents], emitting an empty list when no
/// events exist so the presentation layer can show an empty-state indication
/// (R6.9). Depends only on the abstract [AdminRepository], so it carries no
/// backend types.
class ListEvents {
  const ListEvents(this._repository);

  final AdminRepository _repository;

  /// Returns the stream of all events.
  Stream<List<Event>> call() => _repository.listEvents();
}
