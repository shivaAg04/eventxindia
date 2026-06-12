import '../../../reports/domain/entities/report.dart';
import '../repositories/admin_repository.dart';

/// Streams all submitted reports for the Admin reports view (R6.8, R6.9).
///
/// Delegates to [AdminRepository.listReports], emitting an empty list when no
/// reports exist so the presentation layer can show an empty-state indication
/// (R6.9). Depends only on the abstract [AdminRepository], so it carries no
/// backend types.
class ListReports {
  const ListReports(this._repository);

  final AdminRepository _repository;

  /// Returns the stream of all submitted reports.
  Stream<List<Report>> call() => _repository.listReports();
}
