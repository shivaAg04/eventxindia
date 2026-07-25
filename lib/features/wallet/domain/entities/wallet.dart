import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/money.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import 'withdrawal_request.dart';

/// A student's wallet: the money credited from completed events together with
/// their withdrawal requests, and the balances derived from both.
///
/// This is a *derived, read-only projection* (bookkeeping only — V1 has no real
/// payout gateway). [credited] is the trusted earnings total accrued from
/// completed attendance. Balances are computed purely from [credited] and the
/// [withdrawals], so no separate ledger or backend maintenance is needed:
///
/// * [approvedTotal] — money already withdrawn (approved requests).
/// * [pendingTotal] — money held by requests still awaiting a decision.
/// * [available] — what the student may still request:
///   `credited − approvedTotal − pendingTotal`, never negative.
class Wallet extends Equatable {
  const Wallet({
    required this.studentId,
    required this.credited,
    required this.creditsPerEvent,
    required this.withdrawals,
    this.eventNames = const <String, String>{},
  });

  /// An empty wallet: nothing credited and no requests.
  factory Wallet.empty(String studentId) => Wallet(
        studentId: studentId,
        credited: Money.zero,
        creditsPerEvent: const <String, Money>{},
        withdrawals: const <WithdrawalRequest>[],
      );

  /// The id of the student this wallet belongs to.
  final String studentId;

  /// The total credited from completed events (the trusted earnings total).
  final Money credited;

  /// The amount credited for each completed event, keyed by event id — the
  /// "money in" side of the transaction history.
  final Map<String, Money> creditsPerEvent;

  /// Display name (title) for each credited event, keyed by event id, so the
  /// transaction history can show the event's name instead of its raw id. May
  /// omit an id whose title snapshot was unavailable; callers fall back to the
  /// id in that case.
  final Map<String, String> eventNames;

  /// Every withdrawal request the student has made, newest first.
  final List<WithdrawalRequest> withdrawals;

  int _sumMinor(WithdrawalStatus status) => withdrawals
      .where((WithdrawalRequest w) => w.status == status)
      .fold<int>(0, (int sum, WithdrawalRequest w) => sum + w.amount.minorUnits);

  /// Money already withdrawn (approved requests).
  Money get approvedTotal => Money.fromMinorUnits(
        _sumMinor(WithdrawalStatus.approved),
        requirePayPerHeadRange: false,
      );

  /// Money held by still-pending requests.
  Money get pendingTotal => Money.fromMinorUnits(
        _sumMinor(WithdrawalStatus.pending),
        requirePayPerHeadRange: false,
      );

  /// The amount the student may still request, never negative.
  Money get available {
    final int minor = credited.minorUnits -
        _sumMinor(WithdrawalStatus.approved) -
        _sumMinor(WithdrawalStatus.pending);
    return Money.fromMinorUnits(
      minor < 0 ? 0 : minor,
      requirePayPerHeadRange: false,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[studentId, credited, creditsPerEvent, withdrawals, eventNames];
}
