import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/money.dart';
import '../../../../core/value_objects/withdrawal_status.dart';

/// A student's request to withdraw money from their wallet.
///
/// This is bookkeeping only — V1 has no real payout gateway. A request is
/// created [WithdrawalStatus.pending] by the student and later moved to
/// approved or rejected by an admin. The [amount] is a [Money] value; the
/// wallet's available balance guards how much can be requested.
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only.
class WithdrawalRequest extends Equatable {
  const WithdrawalRequest({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.decidedAt,
  });

  /// Creates a brand-new, [WithdrawalStatus.pending] request for [studentId].
  ///
  /// The [id] is derived from [now] so it is stable and unique per request.
  factory WithdrawalRequest.create({
    required String studentId,
    required Money amount,
    required DateTime now,
  }) {
    return WithdrawalRequest(
      id: 'wd_${now.microsecondsSinceEpoch}',
      studentId: studentId,
      amount: amount,
      status: WithdrawalStatus.pending,
      createdAt: now,
    );
  }

  /// The unique id of this request (also the document id).
  final String id;

  /// The id of the requesting student.
  final String studentId;

  /// The amount requested.
  final Money amount;

  /// The current review status of the request.
  final WithdrawalStatus status;

  /// When the request was created.
  final DateTime createdAt;

  /// When an admin decided the request, or `null` while still pending.
  final DateTime? decidedAt;

  /// Whether the request is still awaiting an admin decision.
  bool get isPending => status == WithdrawalStatus.pending;

  /// Returns a copy of this request with the given fields replaced.
  WithdrawalRequest copyWith({
    WithdrawalStatus? status,
    DateTime? decidedAt,
  }) {
    return WithdrawalRequest(
      id: id,
      studentId: studentId,
      amount: amount,
      status: status ?? this.status,
      createdAt: createdAt,
      decidedAt: decidedAt ?? this.decidedAt,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[id, studentId, amount, status, createdAt, decidedAt];
}
