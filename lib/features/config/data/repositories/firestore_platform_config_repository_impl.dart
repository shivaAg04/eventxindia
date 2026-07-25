import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/platform_config_repository.dart';
import '../datasources/firestore_platform_config_data_source.dart';

/// Firestore-backed implementation of [PlatformConfigRepository].
///
/// Reads/streams the `config/platform` document's commission percentage
/// (defaulting to [kDefaultCommissionPercent] when unset) and writes it through
/// the shared write-retry policy. No Firebase type crosses into the domain.
@LazySingleton(as: PlatformConfigRepository)
class FirestorePlatformConfigRepositoryImpl
    implements PlatformConfigRepository {
  const FirestorePlatformConfigRepositoryImpl(this._dataSource);

  final FirestorePlatformConfigDataSource _dataSource;

  @override
  Stream<int> watchCommissionPercent() =>
      _dataSource.watchCommissionPercent();

  @override
  Future<Result<int, Failure>> getCommissionPercent() async {
    try {
      return Result<int, Failure>.ok(await _dataSource.getCommissionPercent());
    } catch (_) {
      // A read failure falls back to the default so event creation is never
      // blocked by config being unreadable.
      return const Result<int, Failure>.ok(kDefaultCommissionPercent);
    }
  }

  @override
  Future<Result<Unit, Failure>> setCommissionPercent(int percent) {
    return withRetry<Unit>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.setCommissionPercent(percent);
        return unit;
      },
    );
  }
}
