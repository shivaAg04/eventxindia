import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/report.dart';

/// Intents the report-submission UI sends to the `ReportBloc`.
sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// The report form fields changed.
///
/// Carries the latest [category] (or `null` when the selection was cleared) and
/// the raw [description] text so the BLoC simply replaces its held draft,
/// guaranteeing the entered values are retained verbatim and any previously
/// shown field errors are cleared so the user can keep editing (R12.3, R12.4).
final class ReportFieldsChanged extends ReportEvent {
  const ReportFieldsChanged({
    this.category,
    this.description = '',
  });

  /// The latest selected category, or `null` when none chosen.
  final ReportCategory? category;

  /// The latest description text as typed.
  final String description;

  @override
  List<Object?> get props => <Object?>[category, description];
}

/// The report form was submitted (R12.1, R12.2).
///
/// [user] is the authenticated submitter whose identity and role are recorded
/// on the report and used to enforce the role/category rule (R12.3). The
/// category and description come from the held draft.
final class ReportSubmitted extends ReportEvent {
  const ReportSubmitted({required this.user});

  /// The authenticated user submitting the report.
  final AuthUser user;

  @override
  List<Object?> get props => <Object?>[user];
}
