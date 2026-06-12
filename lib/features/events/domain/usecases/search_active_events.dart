import '../entities/event.dart';
import '../event_filters.dart';

/// Filters a list of [Event]s by a search query for student discovery (R8.3,
/// R8.4).
///
/// This use case is a thin wrapper over the pure [searchActiveEvents] selector:
/// it returns the active events whose title or location label contains the
/// [query], ignoring letter case. It performs no I/O — discovery streams the
/// active set via `WatchActiveEvents`, and this use case filters that in-memory
/// list as the student types. Returning an empty list signals a no-results
/// indication (R8.4).
class SearchActiveEvents {
  const SearchActiveEvents();

  /// Returns the active events from [events] matching [query] (R8.3).
  List<Event> call(String query, List<Event> events) =>
      searchActiveEvents(query, events);
}
