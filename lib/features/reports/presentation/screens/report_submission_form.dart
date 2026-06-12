import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/report.dart';
import '../../domain/validators/report_validators.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart' as events;
import '../bloc/report_state.dart';

/// A shared report-submission form driven by a [ReportBloc].
///
/// Renders a category selector constrained to the [allowedCategories] for the
/// current submitter and a free-text description field, then submits on behalf
/// of [user]. As the user edits, [ReportFieldsChanged] keeps the bloc's draft
/// in sync so the entered values survive a rejected submission; per-field
/// errors from [ReportEditing.fieldErrors] are surfaced under the offending
/// category (R12.3) or description (R12.4) field, and a successful
/// [ReportSubmitted] / non-validation [ReportFailure] is reported via a
/// snackbar.
///
/// This widget reads its [ReportBloc] from the surrounding [BlocProvider]
/// (created by the student/vendor screen wrappers), so it never talks to a use
/// case or repository directly.
class ReportSubmissionForm extends StatefulWidget {
  const ReportSubmissionForm({
    required this.user,
    required this.allowedCategories,
    super.key,
  });

  /// The authenticated user submitting the report (R12.1, R12.2).
  final AuthUser user;

  /// The categories the submitter's role is permitted to file
  /// ([ReportCategoryX.allowedFor]).
  final List<ReportCategory> allowedCategories;

  @override
  State<ReportSubmissionForm> createState() => _ReportSubmissionFormState();
}

class _ReportSubmissionFormState extends State<ReportSubmissionForm> {
  final TextEditingController _descriptionController = TextEditingController();
  ReportCategory? _category;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onChanged() {
    context.read<ReportBloc>().add(
          events.ReportFieldsChanged(
            category: _category,
            description: _descriptionController.text,
          ),
        );
  }

  void _onCategorySelected(ReportCategory? category) {
    setState(() => _category = category);
    _onChanged();
  }

  void _submit() {
    context.read<ReportBloc>().add(events.ReportSubmitted(user: widget.user));
  }

  /// Returns the first field error message for [field], or `null` when the
  /// current state has no error for it.
  String? _errorFor(ReportState state, String field) {
    if (state is! ReportEditing) {
      return null;
    }
    for (final error in state.fieldErrors) {
      if (error.field == field) {
        return error.message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportBloc, ReportState>(
      listener: (BuildContext context, ReportState state) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        if (state is ReportSubmitted) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Report submitted.')),
            );
        } else if (state is ReportFailure) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (BuildContext context, ReportState state) {
        final bool busy = state is ReportSubmitting;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<ReportCategory>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: const OutlineInputBorder(),
                  errorText: _errorFor(state, ReportFields.category),
                ),
                items: <DropdownMenuItem<ReportCategory>>[
                  for (final category in widget.allowedCategories)
                    DropdownMenuItem<ReportCategory>(
                      value: category,
                      child: Text(_categoryLabel(category)),
                    ),
                ],
                onChanged: busy ? null : _onCategorySelected,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                enabled: !busy,
                maxLines: 5,
                maxLength: Report.maxDescriptionLength,
                onChanged: (_) => _onChanged(),
                decoration: InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: _errorFor(state, ReportFields.description),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit report'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A human-readable label for a [ReportCategory], shown in the selector.
String _categoryLabel(ReportCategory category) {
  switch (category) {
    case ReportCategory.fakeEvent:
      return 'Fake event';
    case ReportCategory.vendorIssue:
      return 'Vendor issue';
    case ReportCategory.noShow:
      return 'No show';
    case ReportCategory.misbehavior:
      return 'Misbehavior';
  }
}
