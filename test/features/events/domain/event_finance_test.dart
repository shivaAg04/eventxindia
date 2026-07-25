import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/events/domain/event_finance.dart';
import 'package:flutter_test/flutter_test.dart';

Event buildEvent({required int payMajor, required int slots}) {
  final DateTime d = DateTime(2026, 1, 1);
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
    slots: slots,
    payPerHead: Money.fromMajorUnits(payMajor),
    status: EventStatus.active,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  group('computeEventFinance', () {
    test('total = pay × slots, distributed = pay × completed, platform = rest',
        () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 100, slots: 10), 4);
      expect(f.total, Money.fromMajorUnits(1000, requirePayPerHeadRange: false));
      expect(f.distributed,
          Money.fromMajorUnits(400, requirePayPerHeadRange: false));
      expect(f.platformShare,
          Money.fromMajorUnits(600, requirePayPerHeadRange: false));
      expect(f.completedCount, 4);
    });

    test('all slots completed distributes the whole total', () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 50, slots: 5), 5);
      expect(f.distributed, f.total);
      expect(f.platformShare, Money.zero);
    });

    test('completedCount is clamped to slots', () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 50, slots: 5), 9);
      expect(f.completedCount, 5);
      expect(f.distributed, f.total);
    });

    test('no completions distributes nothing', () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 100, slots: 10), 0);
      expect(f.distributed, Money.zero);
      expect(f.platformShare, f.total);
    });
  });
}
