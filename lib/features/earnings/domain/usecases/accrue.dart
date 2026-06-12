import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/money.dart';
import '../entities/earnings.dart';

/// The minimal description of a completed attendance record needed to credit a
/// student's estimated earnings: which student, which event, and the event's
/// pay-per-head amount.
///
/// This is the input to the pure [accrue] reducer. It is intentionally small
/// and backend-neutral so the accrual rule can be expressed (and
/// property-tested) without depending on the full `AttendanceRecord`/`Event`
/// entities or any backend type. The data layer / trusted [EarningsService]
/// constructs it from a completed attendance record and its event.
class CompletedAttendance extends Equatable {
  /// Creates the completed-record value used to accrue earnings.
  const CompletedAttendance({
    required this.studentId,
    required this.eventId,
    required this.payPerHead,
  });

  /// The id of the student whose attendance completed.
  final String studentId;

  /// The id of the event the student completed attendance for.
  final String eventId;

  /// The event's pay-per-head — the amount to credit for this event (R11.1).
  final Money payPerHead;

  @override
  List<Object?> get props => <Object?>[studentId, eventId, payPerHead];

  @override
  String toString() => 'CompletedAttendance('
      'studentId: $studentId, eventId: $eventId, payPerHead: $payPerHead)';
}

/// Pure, idempotent earnings accrual reducer keyed on `(studentId, eventId)`.
///
/// Given a student's current [earnings] and a [completed] attendance record,
/// returns the updated [Earnings]:
///
/// - If the event has **already** been credited (its id is present in
///   [Earnings.perEvent]) the earnings are returned **unchanged** — a record is
///   never credited twice (R11.2). This is the idempotency guarantee that lets
///   the trusted backend invoke accrual at-least-once while crediting
///   exactly-once.
/// - Otherwise the event's [CompletedAttendance.payPerHead] is added to the
///   [Earnings.total] and recorded against the event id in
///   [Earnings.perEvent] (R11.1, R11.4).
///
/// The reducer is keyed on `(studentId, eventId)`: a [completed] record whose
/// [CompletedAttendance.studentId] does not match [Earnings.studentId] does not
/// belong to these earnings and is returned unchanged.
///
/// This is pure domain logic — no side effects, no backend types — so the same
/// rule runs identically on the client (for reasoning/tests) and behind the
/// trusted [EarningsService].
Earnings accrue(Earnings earnings, CompletedAttendance completed) {
  // Key part 1 — student: a record for a different student is not ours.
  if (completed.studentId != earnings.studentId) {
    return earnings;
  }

  // Key part 2 — event: already credited, so crediting again is a no-op
  // (R11.2). This is what makes the reducer idempotent.
  if (earnings.perEvent.containsKey(completed.eventId)) {
    return earnings;
  }

  // First time we see this (studentId, eventId): credit exactly once (R11.1).
  final updatedPerEvent = Map<String, Money>.from(earnings.perEvent)
    ..[completed.eventId] = completed.payPerHead;

  return earnings.copyWith(
    total: earnings.total + completed.payPerHead,
    perEvent: updatedPerEvent,
  );
}
