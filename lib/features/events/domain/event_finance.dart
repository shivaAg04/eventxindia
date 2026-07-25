import '../../../core/value_objects/money.dart';
import 'entities/event.dart';

/// The money breakdown for a single event (admin finance reconciliation).
///
/// Computed purely from the event's pay-per-head and capacity plus the number
/// of students who actually completed the event (checked in AND out):
///  * [total] — the full pay budget: `payPerHead × slots` (max distributable).
///  * [distributed] — actually earned by students: `payPerHead × completed`.
///  * [platformShare] — the remainder held back: `total − distributed`.
class EventFinance {
  const EventFinance({
    required this.total,
    required this.distributed,
    required this.platformShare,
    required this.completedCount,
  });

  final Money total;
  final Money distributed;
  final Money platformShare;

  /// How many students completed the event (both check-in and check-out).
  final int completedCount;
}

/// Computes the [EventFinance] for [event] given [completedCount] students who
/// completed it. [completedCount] is clamped into `0..event.slots` so the
/// distributed amount can never exceed the total.
EventFinance computeEventFinance(Event event, int completedCount) {
  final int per = event.payPerHead.minorUnits;
  final int capped =
      completedCount < 0 ? 0 : (completedCount > event.slots ? event.slots : completedCount);
  final int total = per * event.slots;
  final int distributed = per * capped;
  return EventFinance(
    total: Money.fromMinorUnits(total, requirePayPerHeadRange: false),
    distributed:
        Money.fromMinorUnits(distributed, requirePayPerHeadRange: false),
    platformShare:
        Money.fromMinorUnits(total - distributed, requirePayPerHeadRange: false),
    completedCount: capped,
  );
}
