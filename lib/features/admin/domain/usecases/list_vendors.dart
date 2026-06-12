import '../../../profile/domain/entities/vendor.dart';
import '../repositories/admin_repository.dart';

/// Streams all registered vendors, each with its approval status, for the
/// Admin vendor list (R6.5, R6.9).
///
/// Delegates to [AdminRepository.listVendors], emitting an empty list when no
/// vendors are registered so the presentation layer can show an empty-state
/// indication (R6.9). Depends only on the abstract [AdminRepository], so it
/// carries no backend types.
class ListVendors {
  const ListVendors(this._repository);

  final AdminRepository _repository;

  /// Returns the stream of registered vendors.
  Stream<List<Vendor>> call() => _repository.listVendors();
}
