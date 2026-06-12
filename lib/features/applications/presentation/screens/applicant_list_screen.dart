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
/// renders each applicant with approve/reject actions that dispatch
/// [DecideRequested]. Decisions are gated server-side to the owning vendor
/// (R5.9) and to Pending applications (R5.8, R9.5); a rejected action surfaces
/// an [ApplicationFailure] as a snackbar without tearing down the list.
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
          return ListView.separated(
            itemCount: state.applications.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              return _ApplicantTile(
                application: state.applications[index],
                vendorId: widget.vendorId,
              );
            },
          );
        },
      ),
    );
  }
}

/// A single applicant row showing identity and status, with approve/reject
/// actions enabled only while the application is Pending (R5.4, R5.5, R5.8).
class _ApplicantTile extends StatelessWidget {
  const _ApplicantTile({required this.application, required this.vendorId});

  final Application application;
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final bool isPending = application.status == ApplicationStatus.pending;
    return ListTile(
      title: Text(application.studentId),
      subtitle: Text('Status: ${application.status.wireName}'),
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
