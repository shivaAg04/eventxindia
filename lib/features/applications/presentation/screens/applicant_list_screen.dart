import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../domain/entities/application.dart';
import '../../domain/usecases/decide_application.dart';
import '../bloc/application_bloc.dart';
import '../bloc/application_event.dart';
import '../bloc/application_state.dart';

/// Vendor-facing applicant list for a single owned event (R5.3, R5.4, R5.5).
///
/// Subscribes to the event's applications via [ApplicationsWatchStarted] and
/// renders each applicant using the profile snapshot stored on the application
/// at apply time (name, phone, city) — so the vendor identifies the candidate
/// without read access to the student's private profile — with approve/reject
/// actions that dispatch [DecideRequested]. Decisions are gated server-side to
/// the owning vendor (R5.9) and to Pending applications (R5.8, R9.5); a
/// rejected action surfaces an [ApplicationFailure] as a snackbar without
/// tearing down the list.
class ApplicantListScreen extends StatefulWidget {
  const ApplicantListScreen({
    required this.eventId,
    required this.vendorId,
    super.key,
  });

  /// The event whose applicants are displayed.
  final String eventId;

  /// The id of the vendor viewing/deciding (resolved from the session).
  final String vendorId;

  @override
  State<ApplicantListScreen> createState() => _ApplicantListScreenState();
}

class _ApplicantListScreenState extends State<ApplicantListScreen> {
  @override
  void initState() {
    super.initState();
    context
        .read<ApplicationBloc>()
        .add(ApplicationsWatchStarted(eventId: widget.eventId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applicants')),
      body: BlocConsumer<ApplicationBloc, ApplicationState>(
        listenWhen: (_, ApplicationState state) => state is ApplicationFailure,
        listener: (BuildContext context, ApplicationState state) {
          if (state is ApplicationFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.failure.message)),
              );
          }
        },
        buildWhen: (_, ApplicationState state) => state is ApplicationsLoaded,
        builder: (BuildContext context, ApplicationState state) {
          if (state is! ApplicationsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.applications.isEmpty) {
            return const Center(
              child: Text('No applications yet for this event.'),
            );
          }
          final int approved = state.applications
              .where((Application a) => a.status == ApplicationStatus.approved)
              .length;
          final int pending = state.applications
              .where((Application a) => a.status == ApplicationStatus.pending)
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  '$approved approved · $pending pending',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: state.applications.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    return _ApplicantTile(
                      key: ValueKey<String>(
                        state.applications[index].applicationId,
                      ),
                      application: state.applications[index],
                      vendorId: widget.vendorId,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single applicant row showing the candidate's resolved [Student] profile
/// (name, phone, city) and application status, with approve/reject actions
/// enabled only while the application is Pending (R5.4, R5.5, R5.8).
///
/// The student profile is loaded once via [loadStudent] when the row is first
/// built and cached for the row's lifetime; while loading or if the profile
/// cannot be read it falls back to the student id so the vendor can still act.
class _ApplicantTile extends StatelessWidget {
  const _ApplicantTile({
    required this.application,
    required this.vendorId,
    super.key,
  });

  final Application application;
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final ApplicationStatus status = application.status;
    final bool isPending = status == ApplicationStatus.pending;

    // Prefer the profile snapshot stored on the application; fall back to the
    // student id for records created before the snapshot existed.
    final String? name = application.applicantName;
    final List<String> contactBits = <String>[
      if (application.applicantPhone != null) application.applicantPhone!,
      if (application.applicantCity != null) application.applicantCity!,
    ];
    final bool hasDetails = name != null || contactBits.isNotEmpty;

    return ListTile(
      isThreeLine: hasDetails && contactBits.isNotEmpty,
      leading: CircleAvatar(child: Text(_initial(name))),
      title: Text(name ?? application.studentId),
      subtitle: Text(
        contactBits.isEmpty
            ? 'Status: ${status.wireName}'
            : '${contactBits.join(' • ')}\nStatus: ${status.wireName}',
      ),
      trailing: isPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Approve',
                  icon: const Icon(Icons.check_circle_outline),
                  color: Colors.green,
                  onPressed: () => _decide(context, ApplicationDecision.approve),
                ),
                IconButton(
                  tooltip: 'Reject',
                  icon: const Icon(Icons.cancel_outlined),
                  color: Colors.red,
                  onPressed: () => _decide(context, ApplicationDecision.reject),
                ),
              ],
            )
          : null,
    );
  }

  /// The avatar initial from the snapshot name, or '?' when unknown.
  String _initial(String? name) {
    final String trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  void _decide(BuildContext context, ApplicationDecision decision) {
    context.read<ApplicationBloc>().add(
          DecideRequested(
            vendorId: vendorId,
            applicationId: application.applicationId,
            decision: decision,
          ),
        );
  }
}
