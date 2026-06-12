import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/report.dart';

/// The state of the report-submission flow (design BLoC table, R12.1–R12.4).
///
/// Every state carries the current form draft — the selected [category] (or
/// `null` when none chosen yet) and the raw [description] text — so the entered
/// values are preserved across validation failures and in-flight submissions
/// and can be re-rendered verbatim (R12.3, R12.4). The submission screens read
/// the draft and highlight any [ReportEditing.fieldErrors].
sealed class ReportState extends Equatable {
  const ReportState({
    this.category,
    this.description = '',
  });

  /// The currently selected report category, or `null` when none chosen yet.
  final ReportCategory? category;

  /// The free-text description as typed (not yet validated).
  final String description;

  @override
  List<Object?> get props => <Object?>[category, description];
}

/// The editing state: the user is filling in the report form.
///
/// [fieldErrors] is empty while editing and is populated after a rejected
/// submission to identify the invalid category (R12.3) and/or description
/// (R12.4), while [category]/[description] retain the previously entered values.
final class ReportEditing extends ReportState {
  const ReportEditing({
    super.category,
    super.description,
    this.fieldErrors = const <FieldError>[],
  });

  /// The per-field validation errors to surface, empty when there are none.
  final List<FieldError> fieldErrors;

  @override
  List<Object?> get props => <Object?>[category, description, fieldErrors];
}

/// A submission is in flight (validation passed; persistence is running).
final class ReportSubmitting extends ReportState {
  const ReportSubmitting({
    super.category,
    super.description,
  });
}

/// The report was submitted and recorded successfully (R12.1, R12.2, R12.5).
///
/// Carries the persisted [report] so the screen can confirm what was filed.
final class ReportSubmitted extends ReportState {
  const ReportSubmitted({
    required this.report,
    super.category,
    super.description,
  });

  /// The persisted report returned by the use case.
  final Report report;

  @override
  List<Object?> get props => <Object?>[category, description, report];
}

/// A non-validation failure occurred (e.g. an authorization or persistence
/// failure).
///
/// The entered values are still retained so the user can retry without
/// re-typing.
final class ReportFailure extends ReportState {
  const ReportFailure({
    required this.message,
    super.category,
    super.description,
  });

  /// A human-readable description of what went wrong.
  final String message;

  @override
  List<Object?> get props => <Object?>[category, description, message];
}
