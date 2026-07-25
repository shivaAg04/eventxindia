import '../entities/withdrawal_request.dart';
import '../repositories/wallet_repository.dart';

/// Streams the withdrawal requests made by a single student (R11 wallet).
class WatchStudentWithdrawals {
  const WatchStudentWithdrawals({required WalletRepository repository})
      : _repository = repository;

  final WalletRepository _repository;

  Stream<List<WithdrawalRequest>> call(String studentId) =>
      _repository.watchByStudent(studentId);
}
