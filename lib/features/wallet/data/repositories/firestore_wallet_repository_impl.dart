import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/firestore_withdrawal_data_source.dart';
import '../dtos/withdrawal_request_dto.dart';

/// Firestore-backed implementation of [WalletRepository].
///
/// Stores withdrawal requests under the `withdrawals` collection via
/// [FirestoreWithdrawalDataSource], translating between the pure domain
/// [WithdrawalRequest] and the [WithdrawalRequestDto] at the boundary. Every
/// write is wrapped in the data-layer write-retry policy
/// ([kDefaultMaxWriteAttempts]); on exhaustion it returns a [PersistenceFailure]
/// with nothing partially committed.
@LazySingleton(as: WalletRepository)
class FirestoreWalletRepositoryImpl implements WalletRepository {
  const FirestoreWalletRepositoryImpl(this._dataSource);

  final FirestoreWithdrawalDataSource _dataSource;

  @override
  Stream<List<WithdrawalRequest>> watchByStudent(String studentId) {
    return _dataSource.watchByStudent(studentId).map(_toEntities);
  }

  @override
  Stream<List<WithdrawalRequest>> watchAll() {
    return _dataSource.watchAll().map(_toEntities);
  }

  @override
  Future<Result<WithdrawalRequest, Failure>> create(
    WithdrawalRequest request,
  ) async {
    return withRetry<WithdrawalRequest>(
      kDefaultMaxWriteAttempts,
      () async {
        final WithdrawalRequestDto persisted = await _dataSource
            .create(WithdrawalRequestDto.fromEntity(request));
        return persisted.toEntity();
      },
    );
  }

  @override
  Future<Result<Unit, Failure>> decide({
    required String id,
    required WithdrawalStatus decision,
    required DateTime decidedAt,
  }) async {
    return withRetry<Unit>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.updateStatus(id, decision.wireName, decidedAt);
        return unit;
      },
    );
  }

  List<WithdrawalRequest> _toEntities(List<WithdrawalRequestDto> dtos) =>
      dtos.map((WithdrawalRequestDto dto) => dto.toEntity()).toList(
            growable: false,
          );
}
