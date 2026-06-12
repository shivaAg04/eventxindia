import 'package:eventxindia/features/reports/domain/entities/report.dart';
import 'package:eventxindia/features/reports/domain/usecases/list_reports.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  final DateTime now = DateTime(2025, 1, 1, 9);

  Report report(String id) {
    return Report(
      reportId: id,
      submitterId: 's1',
      submitterRole: SubmitterRole.student,
      category: ReportCategory.fakeEvent,
      description: 'Issue $id.',
      createdAt: now,
    );
  }

  group('ListReports', () {
    test('streams all submitted reports (R6.8, R12.6)', () async {
      final repo = FakeReportRepository()
        ..seed(report('r1'))
        ..seed(report('r2'));
      final useCase = ListReports(repository: repo);

      final List<Report> emitted = await useCase().first;

      expect(emitted.map((Report r) => r.reportId),
          containsAll(<String>['r1', 'r2']));
      expect(emitted.length, 2);
    });

    test('streams an empty list when there are no reports', () async {
      final repo = FakeReportRepository();
      final useCase = ListReports(repository: repo);

      expect(await useCase().first, isEmpty);
    });
  });
}
