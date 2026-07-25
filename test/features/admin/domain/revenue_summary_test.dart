import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/admin/domain/revenue_summary.dart';
import 'package:eventxindia/features/attendance/domain/entities/attendance_record.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:flutter_test/flutter_test.dart';

Event buildEvent({
  required String id,
  required int payMajor,
  required int slots,
  required EventStatus status,
  required DateTime date,
}) {
  return Event(
    eventId: id,
    vendorId: 'v1',
    title: 'Event $id',
    description: 'desc',
    date: date,
    startTime: date,
    endTime: date.add(const Duration(hours: 3)),
    location:
        EventLocation(label: 'Venue', geo: GeoPoint(latitude: 1, longitude: 1)),
    slots: slots,
    payPerHead: Money.fromMajorUnits(payMajor),
    status: status,
    createdAt: date,
    updatedAt: date,
  );
}

AttendanceRecord attendance(String eventId, String studentId,
    {required bool completed}) {
  final DateTime t = DateTime(2026, 6, 1, 9);
  return AttendanceRecord(
    attendanceId: '${eventId}_$studentId',
    eventId: eventId,
    studentId: studentId,
    checkInTime: t,
    checkOutTime: completed ? t.add(const Duration(hours: 4)) : null,
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  final DateTime now = DateTime(2026, 7, 2);

  test('aggregates revenue from completed events and total student earnings',
      () {
    final List<Event> events = <Event>[
      // Completed event: ₹100 × 10 slots, 3 completed → revenue 1000, dist 300.
      buildEvent(
        id: 'done',
        payMajor: 100,
        slots: 10,
        status: EventStatus.completed,
        date: DateTime(2026, 6, 1),
      ),
      // Active future event: ₹50 × 5, 2 completed → not in completed revenue,
      // but its earnings count toward studentsEarnedAll.
      buildEvent(
        id: 'live',
        payMajor: 50,
        slots: 5,
        status: EventStatus.active,
        date: DateTime(2026, 7, 20),
      ),
    ];
    final List<AttendanceRecord> att = <AttendanceRecord>[
      attendance('done', 's1', completed: true),
      attendance('done', 's2', completed: true),
      attendance('done', 's3', completed: true),
      attendance('done', 's4', completed: false), // checked in only
      attendance('live', 's5', completed: true),
      attendance('live', 's6', completed: true),
    ];

    final RevenueSummary s = computeRevenueSummary(events, att, now);

    expect(s.completedEventCount, 1);
    expect(s.revenue, Money.fromMajorUnits(1000, requirePayPerHeadRange: false));
    expect(
        s.distributed, Money.fromMajorUnits(300, requirePayPerHeadRange: false));
    // Commission is 10% (default snapshot) of the ₹300 distributed = ₹30.
    expect(s.platformCommission,
        Money.fromMajorUnits(30, requirePayPerHeadRange: false));
    // Students take home the NET of the 10% commission across every event:
    // 3 × (₹100−₹10) + 2 × (₹50−₹5) = 270 + 90 = 360.
    expect(s.studentsEarnedAll,
        Money.fromMajorUnits(360, requirePayPerHeadRange: false));
    expect(s.events.single.eventId, 'done');
    expect(s.events.single.completedCount, 3);
    // The completed 'done' event: ₹300 gross distributed → ₹270 net to students.
    expect(s.events.single.studentEarnings,
        Money.fromMajorUnits(270, requirePayPerHeadRange: false));
    expect(s.events.single.platformCommission,
        Money.fromMajorUnits(30, requirePayPerHeadRange: false));
  });

  test('empty inputs yield a zero summary', () {
    final RevenueSummary s = computeRevenueSummary(
        const <Event>[], const <AttendanceRecord>[], now);
    expect(s.completedEventCount, 0);
    expect(s.revenue, Money.zero);
    expect(s.studentsEarnedAll, Money.zero);
    expect(s.events, isEmpty);
  });
}
