import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../entities/report.dart';
import '../repositories/report_repository.dart';
import '../validators/report_validators.dart';

/// Submits a [Report] on behalf of an authenticated [AuthUser] (R12.1, R12.2,
/// R12.3, R12.4, R12.5).
///
/// The flow is a railway of guards:
///
/// 1. Resolve the submitter's [SubmitterRole] from the user's [UserRole]. Only
///    students and vendors may file reports; an [UserRole.admin] (or any other
///    non-submitting role) short-circuits with an [AuthorizationFailure] and
///    nothing is persisted.
/// 2. Validate the role/category compatibility and description with
///    [validateReport]. Any failure short-circuits with a [ValidationFailure]
///    carrying the exact set of field errors so the presentation layer can
///    highlight the offending category (R12.3) or description (R12.4) while
///    retaining the user's input.
/// 3. Build the [Report] capturing the submitter's identity, role, category,
///    description, and a [createdAt] timestamp, then persist it via
///    [ReportRepository.submit] (R12.1, R12.2, R12.5).
///
/// This is pure domain logic: it depends only on the abstract
/// [ReportRepository] and a [now] clock, never on any backend type, so it is
/// unaffected by a future change of backend.
class SubmitReport {
  /// Creates the use case with its injected [ReportRepository] and a [now]
  /// clock used to timestamp the report.
  const SubmitReport({
    required ReportRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  final ReportRepository _repository;
  final DateTime Function() _now;

  /// Validates and submits a report from [user].
  ///
  /// [reportId] is the identifier for the new report (the persistence document
  /// id). Returns the persisted [Report] on success, or a [Failure] when the
  /// user's role may not file reports, validation fails, or the write fails.
  Future<Result<Report, Failure>> call({
    required AuthUser user,
    required String reportId,
    required ReportCategory category,
    required String description,
  }) async {
    final SubmitterRole? role = _submitterRoleFor(user.role);
    if (role == null) {
      return const Result<Report, Failure>.err(
        AuthorizationFailure(
          message: 'Only students and vendors can submit reports.',
        ),
      );
    }

    final List<FieldError> fieldErrors =
        validateReport(role, category, description);
    if (fieldErrors.isNotEmpty) {
      return Result<Report, Failure>.err(
        ValidationFailure(fieldErrors: fieldErrors),
      );
    }

    final Report report = Report(
      reportId: reportId,
      submitterId: user.uid,
      submitterRole: role,
      category: category,
      description: description,
      createdAt: _now(),
    );

    return _repository.submit(report);
  }

  /// Maps an authenticated [UserRole] to the [SubmitterRole] permitted to file
  /// reports, or `null` for roles (e.g. [UserRole.admin]) that may not submit.
  static SubmitterRole? _submitterRoleFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return SubmitterRole.student;
      case UserRole.vendor:
        return SubmitterRole.vendor;
      case UserRole.admin:
        return null;
    }
  }
}
