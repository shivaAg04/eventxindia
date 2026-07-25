import '../repositories/platform_config_repository.dart';

/// Streams the current platform commission percentage for the admin settings
/// view.
class WatchCommissionPercent {
  const WatchCommissionPercent({required PlatformConfigRepository repository})
      : _repository = repository;

  final PlatformConfigRepository _repository;

  Stream<int> call() => _repository.watchCommissionPercent();
}
