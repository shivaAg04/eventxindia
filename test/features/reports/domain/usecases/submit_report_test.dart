import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/auth/domain/entities/auth_user.dart';
import 'package:eventxindia/features/auth/domain/entities/user_role.dart';
import 'package:eventxindia/features/reports/domain/entities/report.dart';
import 'package:eventxindia/features/reports/domain/usecases/submit_report.dart';
import 'package:eventxindia/features/reports/domain/validators/report_validators.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  final DateTime fixedNow = DateTime(2025, 1, 1, 9);

  AuthUser user(UserRole role, {String uid = 'u1'}) {
    return AuthUser(
      uid: uid,
      role: role,
      phone: PhoneNumber.national('9876543210'),
    );
  }

  SubmitReport buildUseCase(FakeReportRepository repo) {
    return SubmitReport(repository: repo, now: () => fixedNow);
  }

  group('SubmitReport', () {
    test('records a student report with identity, category, description, and '
        'timestamp (R12.1, R12.5)', () async {
      final repo = FakeReportRepository();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.student, uid: 's1'),
        reportId: 'r1',
        category: ReportCategory.fakeEvent,
        description: 'This event was fake.',
      );

      expect(result.isOk, isTrue);
      final Report report = result.valueOrNull!;
      expect(report.reportId, 'r1');
      expect(report.submitterId, 's1');
      expect(report.submitterRole, SubmitterRole.student);
      expect(report.category, ReportCategory.fakeEvent);
      expect(report.description, 'This event was fake.');
      expect(report.createdAt, fixedNow);
      expect(repo.submitted.single.reportId, 'r1');
    });

    test('records a vendor report with a vendor-only category (R12.2)',
        () async {
      final repo = FakeReportRepository();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.vendor, uid: 'v1'),
        reportId: 'r2',
        category: ReportCategory.misbehavior,
        description: 'Student misbehaved.',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.submitterRole, SubmitterRole.vendor);
    });

    test('rejects a category not permitted for the role and persists nothing '
        '(R12.3)', () async {
      final repo = FakeReportRepository();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.student),
        reportId: 'r3',
        category: ReportCategory.noShow,
        description: 'Valid description.',
      );

      final ValidationFailure failure =
          result.failureOrNull! as ValidationFailure;
      expect(failure.fieldErrors.map((e) => e.field),
          contains(ReportFields.category));
      expect(repo.submitted, isEmpty);
    });

    test('rejects an empty description and persists nothing (R12.4)', () async {
      final repo = FakeReportRepository();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.student),
        reportId: 'r4',
        category: ReportCategory.fakeEvent,
        description: '',
      );

      final ValidationFailure failure =
          result.failureOrNull! as ValidationFailure;
      expect(failure.fieldErrors.map((e) => e.field),
          contains(ReportFields.description));
      expect(repo.submitted, isEmpty);
    });

    test('rejects a description longer than the maximum (R12.4)', () async {
      final repo = FakeReportRepository();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.student),
        reportId: 'r5',
        category: ReportCategory.fakeEvent,
        description: 'a' * (Report.maxDescriptionLength + 1),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.submitted, isEmpty);
    });

    test('rejects an admin submitter with an authorization failure', () async {
      final repo = FakeReportRepository();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.admin),
        reportId: 'r6',
        category: ReportCategory.fakeEvent,
        description: 'Valid description.',
      );

      expect(result.failureOrNull, isA<AuthorizationFailure>());
      expect(repo.submitted, isEmpty);
    });

    test('surfaces a persistence failure from the repository unchanged (R12.5)',
        () async {
      final repo = FakeReportRepository()
        ..submitFailure = const PersistenceFailure();
      final useCase = buildUseCase(repo);

      final result = await useCase(
        user: user(UserRole.student),
        reportId: 'r7',
        category: ReportCategory.fakeEvent,
        description: 'Valid description.',
      );

      expect(result.failureOrNull, isA<PersistenceFailure>());
    });
  });
}
