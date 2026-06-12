import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/firestore_report_data_source.dart';
import '../dtos/report_dto.dart';

/// Firebase-backed implementation of [ReportRepository].
///
/// Translates between the pure domain [Report] and the Firestore document shape
/// via [ReportDto], delegating raw collection access to a
/// [FirestoreReportDataSource]. The [submit] write is wrapped in the
/// data-layer retry policy [withRetry] (R14.6, Property 29): the write is
/// attempted at most [kDefaultMaxWriteAttempts] (3) times and, on total
/// failure, returns a [PersistenceFailure] without committing partial data
/// (R12.5). [watchAll] exposes the data source's newest-first stream as pure
/// domain entities (R6.8, R12.6).
@LazySingleton(as: ReportRepository)
class FirestoreReportRepositoryImpl implements ReportRepository {
  const FirestoreReportRepositoryImpl(this._dataSource);

  final FirestoreReportDataSource _dataSource;

  @override
  Future<Result<Report, Failure>> submit(Report report) {
    final ReportDto dto = ReportDto.fromEntity(report);
    return withRetry<Report>(
      kDefaultMaxWriteAttempts,
      () async {
        final ReportDto stored = await _dataSource.submit(dto);
        return stored.toEntity();
      },
    );
  }

  @override
  Stream<List<Report>> watchAll() {
    return _dataSource.watchAll().map(
          (List<ReportDto> dtos) => dtos
              .map((ReportDto dto) => dto.toEntity())
              .toList(growable: false),
        );
  }
}
