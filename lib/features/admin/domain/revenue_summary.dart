import '../../../core/value_objects/event_status.dart';
import '../../../core/value_objects/money.dart';
import '../../events/domain/entities/event.dart';
import '../../events/domain/event_status_policy.dart';
import '../../attendance/domain/entities/attendance_record.dart';

/// The money breakdown for one completed event (admin revenue view).
class EventRevenue {
  const EventRevenue({
    required this.eventId,
    required this.title,
    required this.slots,
    required this.completedCount,
    required this.revenue,
    required this.distributed,
    required this.platformShare,
  });

  final String eventId;
  final String title;
  final int slots;
  final int completedCount;

  /// The event's full pay budget: payPerHead × slots.
  final Money revenue;

  /// Money students actually earned on this event: payPerHead × completed.
  final Money distributed;

  /// The platform's remainder: revenue − distributed.
  final Money platformShare;
}

/// The aggregate revenue picture for the admin (R6).
///
/// [revenue]/[distributed]/[platformShare] aggregate the per-event finance over
/// events whose *effective* status is completed. [studentsEarnedAll] is the
/// total money earned by **all** students across every event (the sum of the
/// event pay for each completed attendance record), independent of the event's
/// own status — this matches what lands in students' wallets.
class RevenueSummary {
  const RevenueSummary({
    required this.completedEventCount,
    required this.revenue,
    required this.distributed,
    required this.platformShare,
    required this.studentsEarnedAll,
    required this.events,
  });

  factory RevenueSummary.empty() => const RevenueSummary(
        completedEventCount: 0,
        revenue: Money.zero,
        distributed: Money.zero,
        platformShare: Money.zero,
        studentsEarnedAll: Money.zero,
        events: <EventRevenue>[],
      );

  final int completedEventCount;
  final Money revenue;
  final Money distributed;
  final Money platformShare;
  final Money studentsEarnedAll;

  /// Per completed event, newest-first is not guaranteed; ordered as [events].
  final List<EventRevenue> events;
}

Money _money(int minor) =>
    Money.fromMinorUnits(minor, requirePayPerHeadRange: false);

/// Computes the [RevenueSummary] from every [events] and [attendance] record.
///
/// Pure: no I/O, depends only on its arguments and [now] (used to derive each
/// event's effective status).
RevenueSummary computeRevenueSummary(
  List<Event> events,
  List<AttendanceRecord> attendance,
  DateTime now,
) {
  final Map<String, Event> eventsById = <String, Event>{
    for (final Event e in events) e.eventId: e,
  };

  // Completed-attendance counts per event, and the total students earned.
  final Map<String, int> completedByEvent = <String, int>{};
  int studentsEarnedAllMinor = 0;
  for (final AttendanceRecord r in attendance) {
    final bool completed = r.checkInTime != null && r.checkOutTime != null;
    if (!completed) continue;
    completedByEvent[r.eventId] = (completedByEvent[r.eventId] ?? 0) + 1;
    final Event? e = eventsById[r.eventId];
    if (e != null) {
      studentsEarnedAllMinor += e.payPerHead.minorUnits;
    }
  }

  final List<EventRevenue> perEvent = <EventRevenue>[];
  int revenueMinor = 0;
  int distributedMinor = 0;
  for (final Event e in events) {
    if (effectiveEventStatus(e, now) != EventStatus.completed) continue;
    final int per = e.payPerHead.minorUnits;
    final int completed = completedByEvent[e.eventId] ?? 0;
    final int cappedCompleted = completed > e.slots ? e.slots : completed;
    final int eventRevenue = per * e.slots;
    final int eventDistributed = per * cappedCompleted;
    revenueMinor += eventRevenue;
    distributedMinor += eventDistributed;
    perEvent.add(EventRevenue(
      eventId: e.eventId,
      title: e.title,
      slots: e.slots,
      completedCount: cappedCompleted,
      revenue: _money(eventRevenue),
      distributed: _money(eventDistributed),
      platformShare: _money(eventRevenue - eventDistributed),
    ));
  }

  return RevenueSummary(
    completedEventCount: perEvent.length,
    revenue: _money(revenueMinor),
    distributed: _money(distributedMinor),
    platformShare: _money(revenueMinor - distributedMinor),
    studentsEarnedAll: _money(studentsEarnedAllMinor),
    events: perEvent,
  );
}
