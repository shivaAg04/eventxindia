import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/report.dart';
import '../bloc/report_bloc.dart';
import 'report_submission_form.dart';

/// Screen where a vendor files a report (R12.2).
///
/// Offers only the vendor-permitted categories — [ReportCategory.noShow] and
/// [ReportCategory.misbehavior] ([ReportCategoryX.allowedFor]) — and submits on
/// behalf of the authenticated [user]. The screen owns its [ReportBloc], built
/// from the injected [createBloc] factory, and renders the shared
/// [ReportSubmissionForm].
class VendorReportScreen extends StatelessWidget {
  const VendorReportScreen({
    required this.user,
    required this.createBloc,
    super.key,
  });

  /// The authenticated vendor submitting the report.
  final AuthUser user;

  /// Factory for the screen's [ReportBloc] (typically resolved from DI).
  final ReportBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportBloc>(
      create: (_) => createBloc(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Report an issue')),
        body: ReportSubmissionForm(
          user: user,
          allowedCategories: ReportCategoryX.allowedFor(SubmitterRole.vendor),
        ),
      ),
    );
  }
}
