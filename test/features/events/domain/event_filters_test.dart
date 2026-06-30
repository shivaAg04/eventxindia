import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/events/domain/event_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an [Event] varying only the fields the filters/sorts read.
Event buildEvent({
  required String id,
  String title = 'Event',
  String location = 'Venue',
  DateTime? date,
  double pay = 100,
  EventStatus status = EventStatus.active,
}) {
  final DateTime d = date ?? DateTime(2026, 1, 1);
  return Event(
    eventId: id,
    vendorId: 'v1',
    title: title,
    description: 'desc',
    date: d,
    startTime: d,
    endTime: d.add(const Duration(hours: 3)),
    location: EventLocation(
      label: location,
      geo: GeoPoint(latitude: 1, longitude: 1),
    ),
    slots: 10,
    payPerHead: Money.fromMajorUnits(pay),
    status: status,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  group('sortEvents', () {
    test('dateAsc orders by soonest date, dateDesc reverses it', () {
      final List<Event> events = <Event>[
        buildEvent(id: 'b', date: DateTime(2026, 3, 1)),
        buildEvent(id: 'a', date: DateTime(2026, 1, 1)),
        buildEvent(id: 'c', date: DateTime(2026, 2, 1)),
      ];

      expect(
        sortEvents(events, EventSort.dateAsc).map((Event e) => e.eventId),
        <String>['a', 'c', 'b'],
      );
      expect(
        sortEvents(events, EventSort.dateDesc).map((Event e) => e.eventId),
        <String>['b', 'c', 'a'],
      );
    });

    test('payAsc / payDesc order by pay-per-head', () {
      final List<Event> events = <Event>[
        buildEvent(id: 'mid', pay: 300),
        buildEvent(id: 'low', pay: 100),
        buildEvent(id: 'high', pay: 500),
      ];

      expect(
        sortEvents(events, EventSort.payAsc).map((Event e) => e.eventId),
        <String>['low', 'mid', 'high'],
      );
      expect(
        sortEvents(events, EventSort.payDesc).map((Event e) => e.eventId),
        <String>['high', 'mid', 'low'],
      );
    });

    test('does not mutate the input list', () {
      final List<Event> events = <Event>[
        buildEvent(id: 'b', date: DateTime(2026, 3, 1)),
        buildEvent(id: 'a', date: DateTime(2026, 1, 1)),
      ];

      sortEvents(events, EventSort.dateAsc);

      expect(events.map((Event e) => e.eventId), <String>['b', 'a']);
    });
  });

  group('filterByDateRange', () {
    final List<Event> events = <Event>[
      buildEvent(id: 'jan', date: DateTime(2026, 1, 15)),
      buildEvent(id: 'feb', date: DateTime(2026, 2, 15)),
      buildEvent(id: 'mar', date: DateTime(2026, 3, 15)),
    ];

    test('keeps events within the inclusive range', () {
      final List<Event> result = filterByDateRange(
        events,
        start: DateTime(2026, 2, 1),
        end: DateTime(2026, 3, 1),
      );
      expect(result.map((Event e) => e.eventId), <String>['feb']);
    });

    test('is inclusive of the end day regardless of time of day', () {
      final List<Event> result = filterByDateRange(
        events,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 2, 15, 23, 59),
      );
      expect(result.map((Event e) => e.eventId), <String>['jan', 'feb']);
    });

    test('open-ended bounds and a null/null range', () {
      expect(
        filterByDateRange(events, start: DateTime(2026, 2, 1))
            .map((Event e) => e.eventId),
        <String>['feb', 'mar'],
      );
      expect(
        filterByDateRange(events, end: DateTime(2026, 2, 1))
            .map((Event e) => e.eventId),
        <String>['jan'],
      );
      expect(filterByDateRange(events).length, 3);
    });
  });
}
