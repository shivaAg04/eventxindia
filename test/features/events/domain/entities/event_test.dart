import 'package:eventxindia/core/value_objects/approval_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Event buildEvent() {
    final now = DateTime(2025, 1, 1, 9);
    return Event(
      eventId: 'e1',
      vendorId: 'v1',
      title: 'Catering Help',
      description: 'Serve guests at a wedding.',
      date: DateTime(2025, 6, 1),
      startTime: DateTime(2025, 6, 1, 18),
      endTime: DateTime(2025, 6, 1, 23),
      location: EventLocation(
        label: 'Grand Hall',
        geo: GeoPoint(latitude: 12.34, longitude: 56.78),
      ),
      slots: 25,
      payPerHead: Money.fromMajorUnits(500),
      status: EventStatus.active,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Event', () {
    test('holds all provided fields with optional codes null by default', () {
      final event = buildEvent();
      expect(event.eventId, 'e1');
      expect(event.vendorId, 'v1');
      expect(event.status, EventStatus.active);
      expect(event.slots, 25);
      expect(event.startCode, isNull);
      expect(event.endCode, isNull);
      // Defaults to approved so events built/read without the moderation gate
      // (e.g. pre-existing docs) stay published.
      expect(event.approvalStatus, ApprovalStatus.approved);
      expect(event.isPublished, isTrue);
    });

    test('copyWith replaces the moderation approvalStatus', () {
      final event = buildEvent();
      final pending = event.copyWith(approvalStatus: ApprovalStatus.pending);
      expect(pending.approvalStatus, ApprovalStatus.pending);
      expect(pending.isPublished, isFalse);
      expect(pending.eventId, event.eventId);
    });

    test('is value-equal when all fields match', () {
      expect(buildEvent(), buildEvent());
    });

    test('copyWith replaces status while preserving identity fields', () {
      final event = buildEvent();
      final closed = event.copyWith(status: EventStatus.closed);
      expect(closed.status, EventStatus.closed);
      expect(closed.eventId, event.eventId);
      expect(closed.vendorId, event.vendorId);
      expect(closed.createdAt, event.createdAt);
    });

    test('copyWith sets attendance codes', () {
      final event = buildEvent();
      final withCodes = event.copyWith(startCode: '1234', endCode: '5678');
      expect(withCodes.startCode, '1234');
      expect(withCodes.endCode, '5678');
    });

    test('copyWith does not clear an existing code when passed null', () {
      final event = buildEvent().copyWith(startCode: '1234');
      expect(event.copyWith().startCode, '1234');
    });
  });
}
