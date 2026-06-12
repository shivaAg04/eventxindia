import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/events/domain/usecases/get_event.dart';
import 'package:eventxindia/features/events/domain/usecases/search_active_events.dart';
import 'package:eventxindia/features/events/domain/usecases/watch_active_events.dart';
import 'package:eventxindia/features/events/presentation/bloc/event_discovery_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchActiveEvents extends Mock implements WatchActiveEvents {}

class _MockGetEvent extends Mock implements GetEvent {}

final _now = DateTime(2025, 1, 1, 9);

Event _event(String id, {String title = 'Event', String label = 'Hall'}) =>
    Event(
      eventId: id,
      vendorId: 'v1',
      title: title,
      description: 'desc',
      date: DateTime(2025, 6, 1),
      startTime: DateTime(2025, 6, 1, 18),
      endTime: DateTime(2025, 6, 1, 23),
      location: EventLocation(
        label: label,
        geo: GeoPoint(latitude: 12.34, longitude: 56.78),
      ),
      slots: 10,
      payPerHead: Money.fromMajorUnits(500),
      status: EventStatus.active,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  late _MockWatchActiveEvents watchActiveEvents;
  late _MockGetEvent getEvent;
  // SearchActiveEvents is a pure use case with no dependencies; use the real one.
  const searchActiveEvents = SearchActiveEvents();

  setUp(() {
    watchActiveEvents = _MockWatchActiveEvents();
    getEvent = _MockGetEvent();
  });

  EventDiscoveryBloc build() => EventDiscoveryBloc(
        watchActiveEvents,
        searchActiveEvents,
        getEvent,
      );

  void stubStream(List<Event> events) {
    when(watchActiveEvents.call)
        .thenAnswer((_) => Stream<List<Event>>.value(events));
  }

  group('EventDiscoveryBloc', () {
    test('initial state is EventDiscoveryInitial', () {
      stubStream(const <Event>[]);
      expect(build().state, const EventDiscoveryInitial());
    });

    blocTest<EventDiscoveryBloc, EventDiscoveryState>(
      'DiscoveryStarted emits Loading then EventsLoaded with the active set '
      '(R8.1)',
      setUp: () => stubStream(<Event>[_event('e1'), _event('e2')]),
      build: build,
      act: (bloc) => bloc.add(const DiscoveryStarted()),
      expect: () => <Matcher>[
        isA<EventsLoading>(),
        isA<EventsLoaded>().having((s) => s.events.length, 'events', 2),
      ],
    );

    blocTest<EventDiscoveryBloc, EventDiscoveryState>(
      'DiscoveryStarted emits EventsEmpty when no active events exist (R8.2)',
      setUp: () => stubStream(const <Event>[]),
      build: build,
      act: (bloc) => bloc.add(const DiscoveryStarted()),
      expect: () => <Matcher>[
        isA<EventsLoading>(),
        isA<EventsEmpty>(),
      ],
    );

    blocTest<EventDiscoveryBloc, EventDiscoveryState>(
      'SearchQueryChanged filters the cached active set and emits EventsLoaded '
      '(R8.3)',
      setUp: () => stubStream(
        <Event>[
          _event('e1', title: 'Concert'),
          _event('e2', title: 'Wedding'),
        ],
      ),
      build: build,
      act: (bloc) async {
        bloc.add(const DiscoveryStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SearchQueryChanged('concert'));
      },
      skip: 2,
      expect: () => <Matcher>[
        isA<EventsLoaded>()
            .having((s) => s.events.single.eventId, 'matched', 'e1'),
      ],
    );

    blocTest<EventDiscoveryBloc, EventDiscoveryState>(
      'SearchQueryChanged emits SearchNoResults for a non-blank query with no '
      'matches (R8.4)',
      setUp: () => stubStream(<Event>[_event('e1', title: 'Concert')]),
      build: build,
      act: (bloc) async {
        bloc.add(const DiscoveryStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SearchQueryChanged('nomatch'));
      },
      skip: 2,
      expect: () => <Matcher>[
        isA<SearchNoResults>().having((s) => s.query, 'query', 'nomatch'),
      ],
    );

    blocTest<EventDiscoveryBloc, EventDiscoveryState>(
      'EventSelected emits EventDetail on success (R8.5)',
      setUp: () {
        stubStream(<Event>[_event('e1')]);
        when(() => getEvent('e1')).thenAnswer(
          (_) async => Result<Event, Failure>.ok(_event('e1')),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const DiscoveryStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EventSelected('e1'));
      },
      skip: 2,
      expect: () => <Matcher>[
        isA<EventDetail>().having((s) => s.event.eventId, 'eventId', 'e1'),
      ],
    );

    blocTest<EventDiscoveryBloc, EventDiscoveryState>(
      'EventSelected emits EventDiscoveryFailure when the event cannot be read '
      '(R8.5)',
      setUp: () {
        stubStream(<Event>[_event('e1')]);
        when(() => getEvent('missing')).thenAnswer(
          (_) async => const Result<Event, Failure>.err(
            NotFoundFailure(message: 'not found'),
          ),
        );
      },
      build: build,
      act: (bloc) async {
        bloc.add(const DiscoveryStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EventSelected('missing'));
      },
      skip: 2,
      expect: () => <Matcher>[
        isA<EventDiscoveryFailure>(),
      ],
    );
  });
}
