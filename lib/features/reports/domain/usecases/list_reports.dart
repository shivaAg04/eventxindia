import '../entities/report.dart';
import '../repositories/report_repository.dart';

/// Streams every submitted [Report] for the admin reports review (R6.8,
/// R12.6).
///
/// This use case backs the admin's submitted-reports view: it delegates to
/// [ReportRepository.watchAll], emitting the current list of [Report]s and a
/// fresh list whenever it changes (an empty list when no reports have been
/// submitted).
///
/// This is pure domain logic: it depends only on the repository abstraction,
/// never on any backend type.
class ListReports {
  /// Creates the use case with its injected [ReportRepository].
  const ListReports({required ReportRepository repository})
      : _repository = repository;

  final ReportRepository _repository;

  /// Streams all submitted reports.
  Stream<List<Report>> call() => _repository.watchAll();
}
