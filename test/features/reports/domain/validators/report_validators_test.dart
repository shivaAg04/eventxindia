import 'package:eventxindia/features/reports/domain/entities/report.dart';
import 'package:eventxindia/features/reports/domain/validators/report_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateReport', () {
    test('accepts a student with a permitted category and valid description '
        '(R12.1, R12.3, R12.4)', () {
      final errors = validateReport(
        SubmitterRole.student,
        ReportCategory.fakeEvent,
        'This event never happened.',
      );
      expect(errors, isEmpty);
    });

    test('accepts a vendor with a permitted category (R12.2, R12.3)', () {
      final errors = validateReport(
        SubmitterRole.vendor,
        ReportCategory.noShow,
        'The student did not show up.',
      );
      expect(errors, isEmpty);
    });

    test('rejects a category not permitted for the role (R12.3)', () {
      final errors = validateReport(
        SubmitterRole.student,
        ReportCategory.noShow,
        'Valid description.',
      );
      expect(errors, hasLength(1));
      expect(errors.single.field, ReportFields.category);
    });

    test('rejects a vendor using a student-only category (R12.3)', () {
      final errors = validateReport(
        SubmitterRole.vendor,
        ReportCategory.fakeEvent,
        'Valid description.',
      );
      expect(errors.map((e) => e.field), contains(ReportFields.category));
    });

    test('rejects an empty description (R12.4)', () {
      final errors = validateReport(
        SubmitterRole.student,
        ReportCategory.fakeEvent,
        '',
      );
      expect(errors, hasLength(1));
      expect(errors.single.field, ReportFields.description);
    });

    test('rejects a whitespace-only description (R12.4)', () {
      final errors = validateReport(
        SubmitterRole.student,
        ReportCategory.fakeEvent,
        '   ',
      );
      expect(errors.map((e) => e.field), contains(ReportFields.description));
    });

    test('accepts a description of exactly the maximum length (R12.4)', () {
      final errors = validateReport(
        SubmitterRole.student,
        ReportCategory.fakeEvent,
        'a' * Report.maxDescriptionLength,
      );
      expect(errors, isEmpty);
    });

    test('rejects a description longer than the maximum length (R12.4)', () {
      final errors = validateReport(
        SubmitterRole.student,
        ReportCategory.fakeEvent,
        'a' * (Report.maxDescriptionLength + 1),
      );
      expect(errors, hasLength(1));
      expect(errors.single.field, ReportFields.description);
    });

    test('reports both category and description errors together', () {
      final errors = validateReport(
        SubmitterRole.vendor,
        ReportCategory.fakeEvent,
        '',
      );
      expect(errors.map((e) => e.field),
          containsAll(<String>[ReportFields.category, ReportFields.description]));
    });
  });
}
