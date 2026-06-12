import 'dart:async';

import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/reports/domain/entities/report.dart';
import 'package:eventxindia/features/reports/domain/repositories/report_repository.dart';

/// An in-memory [ReportRepository] fake for use-case tests.
class FakeReportRepository implements ReportRepository {
  final Map<String, Report> _reports = <String, Report>{};

  /// Reports passed to [submit], in call order.
  final List<Report> submitted = <Report>[];

  /// When set, [submit] returns this failure instead of persisting.
  Failure? submitFailure;

  /// Seeds the repository with [report], keyed by its id.
  void seed(Report report) => _reports[report.reportId] = report;

  @override
  Future<Result<Report, Failure>> submit(Report report) async {
    if (submitFailure != null) {
      return Result<Report, Failure>.err(submitFailure!);
    }
    submitted.add(report);
    _reports[report.reportId] = report;
    return Result<Report, Failure>.ok(report);
  }

  @override
  Stream<List<Report>> watchAll() =>
      Stream<List<Report>>.value(_reports.values.toList());
}
