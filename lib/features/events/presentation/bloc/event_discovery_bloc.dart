import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart' as core;
import '../../domain/entities/event.dart';
import '../../domain/usecases/get_event.dart';
import '../../domain/usecases/search_active_events.dart';
import '../../domain/usecases/watch_active_events.dart';

part 'event_discovery_event.dart';
part 'event_discovery_state.dart';

/// Presentation-layer state machine for student event discovery, search, and
/// the event-detail view (R8.1–R8.5).
///
/// [EventDiscoveryBloc] translates UI intent ([EventDiscoveryEvent]s) into calls
/// on the discovery use cases and emits [EventDiscoveryState]s the discovery,
/// search, and detail screens render. Per the architecture's dependency rule it
/// depends *only* on use cases ([WatchActiveEvents], [SearchActiveEvents],
/// [GetEvent]) injected via the constructor — never on a repository or any
/// Firebase type.
///
/// Event → state mapping:
/// * [DiscoveryStarted] → `[EventsLoading]`, then streams active events and
///   emits [EventsLoaded] (or [EventsEmpty] when the active set is empty)
///   (R8.1, R8.2).
/// * [SearchQueryChanged] → re-filters the cached active set with
///   [SearchActiveEvents] and emits [EventsLoaded], [SearchNoResults] (when a
///   non-blank query matches nothing), or [EventsEmpty] (R8.3, R8.4).
/// * [EventSelected] → fetches the event with [GetEvent] and emits
///   [EventDetail] on success or [EventDiscoveryFailure] when it cannot be read
///   (R8.5).
@injectable
class EventDiscoveryBloc
    extends Bloc<EventDiscoveryEvent, EventDiscoveryState> {
  EventDiscoveryBloc(
    this._watchActiveEvents,
    this._searchActiveEvents,
    this._getEvent,
  ) : super(const EventDiscoveryInitial()) {
    on<DiscoveryStarted>(_onDiscoveryStarted);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<EventSelected>(_onEventSelected);
    on<_ActiveEventsUpdated>(_onActiveEventsUpdated);
  }

  final WatchActiveEvents _watchActiveEvents;
  final SearchActiveEvents _searchActiveEvents;
  final GetEvent _getEvent;

  /// The most recent active-event set streamed from [WatchActiveEvents], used
  /// as the in-memory source the search filter runs against (R8.3).
  List<Event> _activeEvents = const <Event>[];

  /// The current search query; blank means "show all active events".
  String _query = '';

  StreamSubscription<List<Event>>? _subscription;

  Future<void> _onDiscoveryStarted(
    DiscoveryStarted event,
    Emitter<EventDiscoveryState> emit,
  ) async {
    emit(const EventsLoading());
    await _subscription?.cancel();
    _subscription = _watchActiveEvents().listen(
      (List<Event> events) => add(_ActiveEventsUpdated(events)),
    );
  }

  void _onActiveEventsUpdated(
    _ActiveEventsUpdated event,
    Emitter<EventDiscoveryState> emit,
  ) {
    _activeEvents = event.events;
    // While the student is viewing an event's detail, keep the detail on screen
    // and silently refresh the cache; the list re-renders on the next return.
    if (state is EventDetail) {
      return;
    }
    _emitListState(emit);
  }

  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<EventDiscoveryState> emit,
  ) {
    _query = event.query;
    _emitListState(emit);
  }

  Future<void> _onEventSelected(
    EventSelected event,
    Emitter<EventDiscoveryState> emit,
  ) async {
    final result = await _getEvent(event.eventId);
    result.fold(
      (Event selected) => emit(EventDetail(selected)),
      (core.Failure failure) =>
          emit(EventDiscoveryFailure(failure.message)),
    );
  }

  /// Derives and emits the appropriate list state from the cached active set
  /// and current [_query].
  ///
  /// An empty result with a blank query is an empty active set
  /// ([EventsEmpty]); an empty result with a non-blank query is a no-results
  /// search ([SearchNoResults]); otherwise [EventsLoaded] (R8.2, R8.4).
  void _emitListState(Emitter<EventDiscoveryState> emit) {
    final List<Event> matches = _searchActiveEvents(_query, _activeEvents);
    if (matches.isEmpty) {
      if (_query.trim().isEmpty) {
        emit(const EventsEmpty());
      } else {
        emit(SearchNoResults(_query));
      }
      return;
    }
    emit(EventsLoaded(matches));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
