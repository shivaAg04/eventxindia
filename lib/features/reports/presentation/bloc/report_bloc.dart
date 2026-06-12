import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/submit_report.dart';
import '../../domain/validators/report_validators.dart';
import 'report_event.dart' as events;
import 'report_event.dart' show ReportEvent, ReportFieldsChanged;
import 'report_state.dart';

/// Presentation-layer state machine for submitting a [Report] (design BLoC
/// table, R12.1–R12.4).
///
/// [ReportBloc] translates the report form's intents into a [SubmitReport]
/// call and emits the states the submission screens render. Per the dependency
/// rule it depends *only* on the [SubmitReport] use case (never on a repository
/// or any backend type).
///
/// Event → state mapping:
/// * [ReportFieldsChanged] → [ReportEditing] holding the latest category and
///   description draft with field errors cleared so the user can keep editing.
/// * [ReportSubmitted] → `[ReportSubmitting, ReportSubmitted]` on success, or
///   `[ReportSubmitting, ReportEditing(fieldErrors)]` when validation rejects
///   the category (R12.3) or description (R12.4), or
///   `[ReportSubmitting, ReportFailure]` for any other failure (e.g. an
///   unauthorized role or a persistence error). The entered values are always
///   retained so the user can correct and retry.
///
/// The new report's document id is left to the data layer: an empty
/// [reportId] tells the Firestore data source to allocate one, so the BLoC
/// needs no id generator of its own.
@injectable
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc(this._submitReport) : super(const ReportEditing()) {
    on<ReportFieldsChanged>(_onFieldsChanged);
    on<events.ReportSubmitted>(_onSubmitted);
  }

  final SubmitReport _submitReport;

  /// Replaces the held draft with the latest category/description and clears
  /// any previously shown field errors so the user can keep editing.
  void _onFieldsChanged(
    ReportFieldsChanged event,
    Emitter<ReportState> emit,
  ) {
    emit(ReportEditing(
      category: event.category,
      description: event.description,
    ));
  }

  /// Validates and submits the held report draft, retaining the entered values
  /// on every outcome.
  ///
  /// A missing category is reported as a category field error without calling
  /// the use case (the use case requires a non-null category). Otherwise the
  /// [SubmitReport] use case enforces the role/category rule (R12.3) and the
  /// description bounds (R12.4); a [ValidationFailure] is mapped back to a
  /// [ReportEditing] carrying the per-field errors, and any other [Failure]
  /// becomes a [ReportFailure].
  Future<void> _onSubmitted(
    events.ReportSubmitted event,
    Emitter<ReportState> emit,
  ) async {
    final ReportCategory? category = state.category;
    final String description = state.description;

    if (category == null) {
      emit(ReportEditing(
        category: category,
        description: description,
        fieldErrors: const <FieldError>[
          FieldError(
            field: ReportFields.category,
            message: 'Select a category for your report.',
          ),
        ],
      ));
      return;
    }

    emit(ReportSubmitting(
      category: category,
      description: description,
    ));

    final result = await _submitReport.call(
      user: event.user,
      reportId: '',
      category: category,
      description: description,
    );

    result.fold(
      (Report report) => emit(ReportSubmitted(
        report: report,
        category: category,
        description: description,
      )),
      (Failure failure) => _emitFailure(
        emit,
        failure,
        category: category,
        description: description,
      ),
    );
  }

  /// Maps a use-case [failure] to the right state: a [ValidationFailure]
  /// becomes a [ReportEditing] carrying the per-field errors (R12.3, R12.4),
  /// while any other failure becomes a [ReportFailure]. Either way the entered
  /// values are retained.
  void _emitFailure(
    Emitter<ReportState> emit,
    Failure failure, {
    required ReportCategory category,
    required String description,
  }) {
    if (failure is ValidationFailure) {
      emit(ReportEditing(
        category: category,
        description: description,
        fieldErrors: failure.fieldErrors,
      ));
      return;
    }

    emit(ReportFailure(
      message: failure.message,
      category: category,
      description: description,
    ));
  }
}
