part of 'event_discovery_bloc.dart';

/// Base type for all [EventDiscoveryBloc] states rendered by the discovery,
/// search, and detail screens.
///
/// States are compared by [Equatable] so the widget layer rebuilds only on a
/// genuine state change and `bloc_test` can assert exact emission sequences.
sealed class EventDiscoveryState extends Equatable {
  const EventDiscoveryState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The idle/initial state before discovery has started.
final class EventDiscoveryInitial extends EventDiscoveryState {
  const EventDiscoveryInitial();
}

/// The active-event stream is being established (after [DiscoveryStarted]).
final class EventsLoading extends EventDiscoveryState {
  const EventsLoading();
}

/// Active events (optionally filtered by the current search query) are
/// available for display (R8.1, R8.3).
final class EventsLoaded extends EventDiscoveryState {
  const EventsLoaded(this.events);

  /// The events to render, in repository/stream order.
  final List<Event> events;

  @override
  List<Object?> get props => <Object?>[events];
}

/// No active events are available at all (R8.2).
final class EventsEmpty extends EventDiscoveryState {
  const EventsEmpty();
}

/// A non-blank search [query] matched no active events (R8.4).
final class SearchNoResults extends EventDiscoveryState {
  const SearchNoResults(this.query);

  /// The query that produced no matches.
  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// A single event's detail is loaded for display (R8.5).
final class EventDetail extends EventDiscoveryState {
  const EventDetail(this.event);

  /// The selected event to render in full.
  final Event event;

  @override
  List<Object?> get props => <Object?>[event];
}

/// An event detail could not be loaded — e.g. the event no longer exists or a
/// read failed (R8.5).
final class EventDiscoveryFailure extends EventDiscoveryState {
  const EventDiscoveryFailure(this.message);

  /// A human-readable description of why discovery/detail failed.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
