import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/money.dart';
import '../entities/withdrawal_request.dart';
import '../repositories/wallet_repository.dart';

/// Creates a student's wallet withdrawal request after validating the amount
/// against their available balance.
///
/// Guards (all rejections leave the wallet unchanged):
/// 1. [amount] must be greater than zero.
/// 2. [amount] must not exceed [available] — the student cannot request more
///    than their credited-minus-already-requested balance.
/// On success a [WithdrawalRequest.create] (status Pending) is persisted via
/// [WalletRepository.create].
///
/// This is pure domain logic: it depends only on the repository abstraction and
/// a [now] clock.
class RequestWithdrawal {
  const RequestWithdrawal({
    required WalletRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  final WalletRepository _repository;
  final DateTime Function() _now;

  /// Requests a withdrawal of [amount] for [studentId], bounded by [available].
  Future<Result<WithdrawalRequest, Failure>> call({
    required String studentId,
    required Money amount,
    required Money available,
  }) async {
    if (amount.minorUnits <= 0) {
      return const Result<WithdrawalRequest, Failure>.err(
        ValidationFailure(
          message: 'Enter an amount greater than zero.',
          fieldErrors: <FieldError>[
            FieldError(field: 'amount', message: 'Enter an amount.'),
          ],
        ),
      );
    }
    if (amount.minorUnits > available.minorUnits) {
      return Result<WithdrawalRequest, Failure>.err(
        ValidationFailure(
          message: 'Amount exceeds your available balance of '
              '₹${available.formatted}.',
          fieldErrors: const <FieldError>[
            FieldError(field: 'amount', message: 'Not enough balance.'),
          ],
        ),
      );
    }

    final WithdrawalRequest request = WithdrawalRequest.create(
      studentId: studentId,
      amount: amount,
      now: _now(),
    );
    return _repository.create(request);
  }
}
