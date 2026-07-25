import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/platform_config_repository.dart';

/// Sets the platform commission percentage (admin only).
///
/// Rejects a value outside [kMinCommissionPercent]..[kMaxCommissionPercent] with
/// a [ValidationFailure] before any write. Changing this never affects past
/// events — each event snapshots the rate in force when it was created.
class SetCommissionPercent {
  const SetCommissionPercent({required PlatformConfigRepository repository})
      : _repository = repository;

  final PlatformConfigRepository _repository;

  Future<Result<Unit, Failure>> call(int percent) {
    if (percent < kMinCommissionPercent || percent > kMaxCommissionPercent) {
      return Future<Result<Unit, Failure>>.value(
        const Result<Unit, Failure>.err(
          ValidationFailure(
            message: 'Commission must be between 0 and 100 percent.',
            fieldErrors: <FieldError>[
              FieldError(
                field: 'commissionPercent',
                message: 'Enter a value from 0 to 100.',
              ),
            ],
          ),
        ),
      );
    }
    return _repository.setCommissionPercent(percent);
  }
}
