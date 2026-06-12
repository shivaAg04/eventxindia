import '../../../../core/error/failure.dart';
import '../entities/report.dart';

/// The canonical field names used in [FieldError]s so the presentation layer
/// can map each report-validation error back to the form field that produced
/// it.
abstract final class ReportFields {
  /// The category selector field (R12.3).
  static const String category = 'category';

  /// The free-text description field (R12.4).
  static const String description = 'description';
}

/// Validates a report submission against the role/category and description
/// rules of R12.3–R12.4, returning the exact set of [FieldError]s.
///
/// An empty list means the input is valid. This is a pure function: it performs
/// no I/O and depends only on its arguments.
///
/// The checks performed:
/// * [category] must be permitted for the submitter's [role]
///   ([ReportCategoryX.isAllowedFor]); otherwise a [ReportFields.category] error
///   is reported (R12.3).
/// * [description] must be 1..[Report.maxDescriptionLength] characters after
///   no trimming (an empty or whitespace-only value is rejected, and a value
///   longer than the maximum is rejected); otherwise a
///   [ReportFields.description] error is reported (R12.4).
List<FieldError> validateReport(
  SubmitterRole role,
  ReportCategory category,
  String description,
) {
  final List<FieldError> errors = <FieldError>[];

  if (!category.isAllowedFor(role)) {
    errors.add(const FieldError(
      field: ReportFields.category,
      message: 'The selected category is not permitted for your role.',
    ));
  }

  if (description.trim().isEmpty) {
    errors.add(const FieldError(
      field: ReportFields.description,
      message: 'Description is required.',
    ));
  } else if (description.length > Report.maxDescriptionLength) {
    errors.add(const FieldError(
      field: ReportFields.description,
      message: 'Description must be at most '
          '${Report.maxDescriptionLength} characters.',
    ));
  }

  return errors;
}
