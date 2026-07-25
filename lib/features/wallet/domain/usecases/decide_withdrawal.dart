import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../repositories/wallet_repository.dart';

/// The decision an admin can make on a pending withdrawal request.
enum WithdrawalDecision { approve, reject }

/// Records an admin's decision (approve/reject) on a withdrawal request.
///
/// The [WithdrawalDecision] maps to the persisted [WithdrawalStatus]; the
/// repository stamps the decision time. This is pure domain logic depending
/// only on the repository abstraction and a [now] clock.
class DecideWithdrawal {
  const DecideWithdrawal({
    required WalletRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  final WalletRepository _repository;
  final DateTime Function() _now;

  Future<Result<Unit, Failure>> call({
    required String withdrawalId,
    required WithdrawalDecision decision,
  }) {
    final WithdrawalStatus status = decision == WithdrawalDecision.approve
        ? WithdrawalStatus.approved
        : WithdrawalStatus.rejected;
    return _repository.decide(
      id: withdrawalId,
      decision: status,
      decidedAt: _now(),
    );
  }
}
