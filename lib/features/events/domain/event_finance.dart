import '../../../core/value_objects/money.dart';
import 'entities/event.dart';

/// Splits a gross amount (in minor units) earned for completed work into the
/// platform commission and the student's take-home net, given a whole-number
/// [commissionPercent].
///
/// The commission is floored to whole minor units and the student net is the
/// remainder, so the two **always sum back to [grossMinor]** exactly — no paise
/// is created or lost by rounding. The percentage is treated as `0..100`;
/// callers pass the event's *snapshotted* rate so past events are immutable.
///
/// Money model (R6): the vendor funds the full pay-per-head; the platform keeps
/// [CommissionSplit.commissionMinor] and the student receives
/// [CommissionSplit.studentNetMinor]. e.g. pay ₹100 at 10% ⇒ ₹10 to the
/// platform, ₹90 to the student.
class CommissionSplit {
  const CommissionSplit({
    required this.studentNetMinor,
    required this.commissionMinor,
  });

  /// What the student takes home (minor units).
  final int studentNetMinor;

  /// The platform's commission / admin's cut (minor units).
  final int commissionMinor;
}

/// Pure commission split — see [CommissionSplit]. Guarantees
/// `studentNetMinor + commissionMinor == grossMinor`.
CommissionSplit splitCommission(int grossMinor, int commissionPercent) {
  final int commission = (grossMinor * commissionPercent) ~/ 100;
  return CommissionSplit(
    studentNetMinor: grossMinor - commission,
    commissionMinor: commission,
  );
}

/// The money breakdown for a single event (admin finance reconciliation).
///
/// Computed purely from the event's pay-per-head, capacity, the number of
/// students who actually completed the event (checked in AND out), and the
/// event's **snapshotted** platform commission percentage:
///  * [total] — the full pay budget the vendor funds: `payPerHead × slots`.
///  * [distributed] — the gross paid for completed work: `payPerHead ×
///    completed`. It splits into [studentEarnings] + [platformCommission].
///  * [platformCommission] — the admin's cut: `distributed × commissionPercent%`
///    (floored to whole minor units).
///  * [studentEarnings] — what lands in student wallets: `distributed −
///    platformCommission`.
///
/// The [commissionPercent] is the rate that was in force when the event was
/// created (`event.platformCommissionPercent`), so changing the platform-wide
/// rate later never changes this event's numbers.
class EventFinance {
  const EventFinance({
    required this.total,
    required this.distributed,
    required this.studentEarnings,
    required this.platformCommission,
    required this.commissionPercent,
    required this.completedCount,
  });

  final Money total;

  /// The gross paid for completed work (`payPerHead × completed`), before the
  /// commission split. Equals [studentEarnings] + [platformCommission].
  final Money distributed;

  /// What students actually take home: [distributed] − [platformCommission].
  final Money studentEarnings;

  /// The platform commission (admin's cut) on the distributed amount.
  final Money platformCommission;

  /// The commission percentage snapshotted on the event.
  final int commissionPercent;

  /// How many students completed the event (both check-in and check-out).
  final int completedCount;
}

/// Computes the [EventFinance] for [event] given [completedCount] students who
/// completed it. [completedCount] is clamped into `0..event.slots` so the
/// distributed amount can never exceed the total.
EventFinance computeEventFinance(Event event, int completedCount) {
  final int per = event.payPerHead.minorUnits;
  final int capped = completedCount < 0
      ? 0
      : (completedCount > event.slots ? event.slots : completedCount);
  final int total = per * event.slots;
  final int distributed = per * capped;
  final CommissionSplit split =
      splitCommission(distributed, event.platformCommissionPercent);
  return EventFinance(
    total: Money.fromMinorUnits(total, requirePayPerHeadRange: false),
    distributed:
        Money.fromMinorUnits(distributed, requirePayPerHeadRange: false),
    studentEarnings: Money.fromMinorUnits(split.studentNetMinor,
        requirePayPerHeadRange: false),
    platformCommission: Money.fromMinorUnits(split.commissionMinor,
        requirePayPerHeadRange: false),
    commissionPercent: event.platformCommissionPercent,
    completedCount: capped,
  );
}
