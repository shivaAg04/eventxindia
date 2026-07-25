import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/events/domain/event_status_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an [Event] varying only the date and status the policy reads.
Event buildEvent({
  DateTime? date,
  EventStatus status = EventStatus.active,
}) {
  final DateTime d = date ?? DateTime(2026, 1, 1);
  return Event(
    eventId: 'e1',
    vendorId: 'v1',
    title: 'Event',
    description: 'desc',
    date: d,
    startTime: d,
    endTime: d.add(const Duration(hours: 3)),
    location: EventLocation(
      label: 'Venue',
      geo: GeoPoint(latitude: 1, longitude: 1),
    ),
    slots: 10,
    payPerHead: Money.fromMajorUnits(100),
    status: status,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  final DateTime now = DateTime(2026, 7, 2, 14, 30);

  group('isDatePast', () {
    test('is true for an earlier calendar day', () {
      expect(isDatePast(DateTime(2026, 7, 1), now), isTrue);
    });

    test('is false for today regardless of time of day', () {
      expect(isDatePast(DateTime(2026, 7, 2, 23, 59), now), isFalse);
      expect(isDatePast(DateTime(2026, 7, 2, 0, 0), now), isFalse);
    });

    test('is false for a future day', () {
      expect(isDatePast(DateTime(2026, 7, 3), now), isFalse);
    });
  });

  group('isEventPast', () {
    test('is true for an event on an earlier calendar day', () {
      expect(isEventPast(buildEvent(date: DateTime(2026, 7, 1)), now), isTrue);
    });

    test('is false for an event later today regardless of time of day', () {
      expect(isEventPast(buildEvent(date: DateTime(2026, 7, 2)), now), isFalse);
      // Even an event whose date is today at 00:00 is not "past".
      expect(
        isEventPast(buildEvent(date: DateTime(2026, 7, 2, 0, 0)), now),
        isFalse,
      );
    });

    test('is false for a future event', () {
      expect(isEventPast(buildEvent(date: DateTime(2026, 7, 3)), now), isFalse);
    });
  });

  group('effectiveEventStatus', () {
    test('an active event whose date passed is completed', () {
      final Event event =
          buildEvent(date: DateTime(2026, 7, 1), status: EventStatus.active);
      expect(effectiveEventStatus(event, now), EventStatus.completed);
    });

    test('an active event today or in the future stays active', () {
      expect(
        effectiveEventStatus(
          buildEvent(date: DateTime(2026, 7, 2), status: EventStatus.active),
          now,
        ),
        EventStatus.active,
      );
      expect(
        effectiveEventStatus(
          buildEvent(date: DateTime(2026, 7, 5), status: EventStatus.active),
          now,
        ),
        EventStatus.active,
      );
    });

    test('a vendor-closed event is preserved even when its date passed', () {
      final Event event =
          buildEvent(date: DateTime(2026, 7, 1), status: EventStatus.closed);
      expect(effectiveEventStatus(event, now), EventStatus.closed);
    });

    test('an already-completed event stays completed', () {
      final Event event = buildEvent(
        date: DateTime(2026, 7, 1),
        status: EventStatus.completed,
      );
      expect(effectiveEventStatus(event, now), EventStatus.completed);
    });
  });

  group('allowedEventTransitions', () {
    test('active can only be closed', () {
      expect(allowedEventTransitions(EventStatus.active),
          <EventStatus>[EventStatus.closed]);
    });

    test('closed is terminal (no further status change)', () {
      expect(allowedEventTransitions(EventStatus.closed),
          const <EventStatus>[]);
    });

    test('completed is terminal', () {
      expect(allowedEventTransitions(EventStatus.completed),
          const <EventStatus>[]);
    });

    test('no transition ever leads back to active', () {
      for (final EventStatus s in EventStatus.values) {
        expect(allowedEventTransitions(s).contains(EventStatus.active), isFalse);
      }
    });
  });
}
