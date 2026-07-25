import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/events/domain/event_finance.dart';
import 'package:flutter_test/flutter_test.dart';

Event buildEvent({
  required int payMajor,
  required int slots,
  int commissionPercent = 10,
}) {
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
    platformCommissionPercent: commissionPercent,
  );
}

void main() {
  group('computeEventFinance', () {
    test('total = pay × slots, distributed = pay × completed, commission = %',
        () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 100, slots: 10), 4);
      expect(f.total, Money.fromMajorUnits(1000, requirePayPerHeadRange: false));
      expect(f.distributed,
          Money.fromMajorUnits(400, requirePayPerHeadRange: false));
      // 10% of the 400 distributed goes to the platform, the rest to students.
      expect(f.platformCommission,
          Money.fromMajorUnits(40, requirePayPerHeadRange: false));
      expect(f.studentEarnings,
          Money.fromMajorUnits(360, requirePayPerHeadRange: false));
      expect(f.commissionPercent, 10);
      expect(f.completedCount, 4);
    });

    test('commission uses the event snapshot percent, not a global one', () {
      final EventFinance f = computeEventFinance(
        buildEvent(payMajor: 100, slots: 10, commissionPercent: 25),
        4,
      );
      // 25% of 400 distributed to the platform, 75% to students.
      expect(f.platformCommission,
          Money.fromMajorUnits(100, requirePayPerHeadRange: false));
      expect(f.studentEarnings,
          Money.fromMajorUnits(300, requirePayPerHeadRange: false));
      expect(f.commissionPercent, 25);
    });

    test('completedCount is clamped to slots', () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 50, slots: 5), 9);
      expect(f.completedCount, 5);
      expect(f.distributed, f.total);
    });

    test('no completions distributes nothing and no commission', () {
      final EventFinance f =
          computeEventFinance(buildEvent(payMajor: 100, slots: 10), 0);
      expect(f.distributed, Money.zero);
      expect(f.platformCommission, Money.zero);
      expect(f.studentEarnings, Money.zero);
    });
  });

  group('Event.studentNetPayPerHead', () {
    test('nets the pay-per-head by the snapshotted commission percent', () {
      expect(
        buildEvent(payMajor: 100, slots: 10).studentNetPayPerHead,
        Money.fromMajorUnits(90, requirePayPerHeadRange: false),
      );
      expect(
        buildEvent(payMajor: 100, slots: 10, commissionPercent: 25)
            .studentNetPayPerHead,
        Money.fromMajorUnits(75, requirePayPerHeadRange: false),
      );
    });
  });

  group('splitCommission', () {
    test('net + commission always sum back to the gross', () {
      for (final int gross in <int>[0, 1, 99, 100, 12345]) {
        for (final int pct in <int>[0, 1, 10, 33, 50, 100]) {
          final CommissionSplit s = splitCommission(gross, pct);
          expect(s.studentNetMinor + s.commissionMinor, gross,
              reason: 'gross=$gross pct=$pct must balance');
          expect(s.commissionMinor, (gross * pct) ~/ 100);
        }
      }
    });

    test('₹100 at 10% leaves the student ₹90 and the platform ₹10', () {
      final CommissionSplit s = splitCommission(10000, 10); // paise
      expect(s.studentNetMinor, 9000);
      expect(s.commissionMinor, 1000);
    });
  });
}
