import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/money.dart';

/// A student's estimated earnings, accumulated from completed attendance.
///
/// Earnings are *estimated only* — V1 has no wallet, withdrawals, or payment
/// processing (R11.6). The [total] is the sum of the [Money] credited for each
/// event the student has completed, and [perEvent] records the exact amount
/// credited for each such event keyed by event id (R11.3, R11.4).
///
/// A student with no completed attendance records has a [total] of
/// [Money.zero] and an empty [perEvent] map (R11.5). Accrual itself is a
/// trusted backend capability ([EarningsService]); this entity is the
/// read-only projection the client observes.
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only, so it is unaffected by a future change of backend.
class Earnings extends Equatable {
  Earnings({
    required this.studentId,
    Money? total,
    Map<String, Money>? perEvent,
  })  : total = total ?? Money.zero,
        perEvent = Map<String, Money>.unmodifiable(
          perEvent ?? const <String, Money>{},
        );

  /// Creates an empty earnings projection for [studentId].
  ///
  /// The [total] defaults to [Money.zero] and [perEvent] is empty, matching the
  /// state of a student with no completed attendance records (R11.5).
  factory Earnings.empty(String studentId) => Earnings(studentId: studentId);

  /// The id of the student these earnings belong to.
  final String studentId;

  /// The estimated earnings total — the sum of every value in [perEvent].
  ///
  /// Defaults to [Money.zero] when no earnings have accrued (R11.3, R11.5).
  final Money total;

  /// The amount credited for each completed event, keyed by event id.
  ///
  /// Empty when no earnings have accrued (R11.4, R11.5). The map is
  /// unmodifiable; use [copyWith] to produce an updated projection.
  final Map<String, Money> perEvent;

  /// Returns a copy of these earnings with the given fields replaced.
  Earnings copyWith({
    Money? total,
    Map<String, Money>? perEvent,
  }) {
    return Earnings(
      studentId: studentId,
      total: total ?? this.total,
      perEvent: perEvent ?? this.perEvent,
    );
  }

  @override
  List<Object?> get props => <Object?>[studentId, total, perEvent];

  @override
  String toString() =>
      'Earnings(studentId: $studentId, total: $total, perEvent: $perEvent)';
}
