import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../domain/entities/application.dart';
import '../../domain/usecases/decide_application.dart';
import '../bloc/application_bloc.dart';
import '../bloc/application_event.dart';
import '../bloc/application_state.dart';
import 'applicant_detail_screen.dart';

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
    required this.getStudent,
    required this.watchStudentRatings,
    super.key,
  });

  /// The event whose applicants are displayed.
  final String eventId;

  /// The id of the vendor viewing/deciding (resolved from the session).
  final String vendorId;

  /// Fetches an applicant's full student profile for the detail view (R5.3).
  final Future<Result<Student, Failure>> Function(String uid) getStudent;

  /// Streams an applicant's received ratings, so the detail view can show the
  /// candidate's overall average rating.
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

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
                      getStudent: widget.getStudent,
                      watchStudentRatings: widget.watchStudentRatings,
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

/// A single applicant row showing the candidate's basic profile (name, city)
/// and application status, with approve/reject actions enabled only while the
/// application is Pending (R5.4, R5.5, R5.8). Tapping the row opens the
/// [ApplicantDetailScreen] with the basic detail.
///
/// The applicant's mobile number is deliberately **not** shown to the vendor,
/// here or on the detail screen, to protect the student's contact detail.
/// Details come from the application's profile snapshot; the row falls back to
/// the student id when the name snapshot is absent so the vendor can still act.
class _ApplicantTile extends StatelessWidget {
  const _ApplicantTile({
    required this.application,
    required this.vendorId,
    required this.getStudent,
    required this.watchStudentRatings,
    super.key,
  });

  final Application application;
  final String vendorId;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

  @override
  Widget build(BuildContext context) {
    final ApplicationStatus status = application.status;
    final bool isPending = status == ApplicationStatus.pending;

    // Prefer the profile snapshot stored on the application; fall back to the
    // student id for records created before the snapshot existed. The phone is
    // intentionally excluded — vendors never see an applicant's mobile number.
    final String? name = application.applicantName;
    final String? city = application.applicantCity;

    return ListTile(
      isThreeLine: city != null && city.isNotEmpty,
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ApplicantDetailScreen(
            application: application,
            getStudent: getStudent,
            ratingsStream: watchStudentRatings(application.studentId),
          ),
        ),
      ),
      leading: CircleAvatar(child: Text(_initial(name))),
      title: Text(name ?? application.studentId),
      subtitle: Text(
        city == null || city.isEmpty
            ? 'Status: ${status.wireName}'
            : '$city\nStatus: ${status.wireName}',
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
