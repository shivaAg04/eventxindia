part of 'event_discovery_bloc.dart';

/// Base type for all [EventDiscoveryBloc] events (UI intents in the student
/// discovery flow).
///
/// Events are pure value objects compared by [Equatable], so duplicate intents
/// are deduplicated by `bloc_test` and equality checks.
sealed class EventDiscoveryEvent extends Equatable {
  const EventDiscoveryEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Starts streaming the active event set for discovery (R8.1, R8.2).
final class DiscoveryStarted extends EventDiscoveryEvent {
  const DiscoveryStarted();
}

/// The student changed the search [query] (R8.3, R8.4).
final class SearchQueryChanged extends EventDiscoveryEvent {
  const SearchQueryChanged(this.query);

  /// The current, raw search text; matched case-insensitively against title and
  /// location label by [SearchActiveEvents].
  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// The student selected the event identified by [eventId] to view its detail
/// (R8.5).
final class EventSelected extends EventDiscoveryEvent {
  const EventSelected(this.eventId);

  /// The id of the event whose detail should be loaded.
  final String eventId;

  @override
  List<Object?> get props => <Object?>[eventId];
}

/// Internal event carrying a fresh active-event set from the
/// [WatchActiveEvents] stream into the bloc's single-threaded event handler.
final class _ActiveEventsUpdated extends EventDiscoveryEvent {
  const _ActiveEventsUpdated(this.events);

  /// The latest active events streamed from the repository.
  final List<Event> events;

  @override
  List<Object?> get props => <Object?>[events];
}
