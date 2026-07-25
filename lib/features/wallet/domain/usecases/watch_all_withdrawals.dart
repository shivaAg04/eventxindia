import '../entities/withdrawal_request.dart';
import '../repositories/wallet_repository.dart';

/// Streams every withdrawal request across all students, for the admin review
/// list (R11 wallet).
class WatchAllWithdrawals {
  const WatchAllWithdrawals({required WalletRepository repository})
      : _repository = repository;

  final WalletRepository _repository;

  Stream<List<WithdrawalRequest>> call() => _repository.watchAll();
}
