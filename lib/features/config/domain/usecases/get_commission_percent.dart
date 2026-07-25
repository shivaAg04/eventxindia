import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/platform_config_repository.dart';

/// Reads the current platform commission percentage, used to snapshot the rate
/// onto a new event at creation time.
class GetCommissionPercent {
  const GetCommissionPercent({required PlatformConfigRepository repository})
      : _repository = repository;

  final PlatformConfigRepository _repository;

  Future<Result<int, Failure>> call() => _repository.getCommissionPercent();
}
