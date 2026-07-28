import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/presentation/bloc/application_bloc.dart';
import '../../../applications/presentation/screens/applicant_list_screen.dart';
import '../../../applications/presentation/screens/vendor_attendance_screen.dart';
import '../../../../core/value_objects/rating.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../../profile/presentation/screens/vendor_profile_screen.dart';
import '../../../staff/presentation/bloc/staff_cubit.dart';
import '../../../staff/presentation/screens/staff_screen.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../domain/entities/event.dart';
import '../../domain/event_status_policy.dart';
import '../bloc/event_management_bloc.dart';
import 'create_event_screen.dart';

/// Submits a vendor's one-time rating of a student for an event.
typedef RateStudentFn = Future<Result<RatingEntry, Failure>> Function({
  required String eventId,
  required String studentId,
  required String vendorId,
  required Rating stars,
});

/// Vendor-facing "Manage Events" screen listing the events the vendor owns
/// (R5.2), split into an **Active** tab and a **Closed / Completed** tab, with
/// controls to change each event's status (R7.5) and to create a new event
/// (R5.1, R7.1).
///
/// The screen subscribes to its [EventManagementBloc] via
/// [VendorEventsWatchStarted] and rebuilds whenever the vendor's event set
/// changes, partitioning the [VendorEventsLoaded] list by [EventStatus] across
/// the two tabs. Status changes dispatch [StatusChangeRequested]; a rejected
/// change (e.g. a non-owner action, R5.9) surfaces an [EventManagementFailure]
/// as a snackbar. Each row opens the event's applicant list to review/decide
/// applications (R5.3–R5.5) and exposes an attendance action opening the
/// per-event attendance view (R5.6, R5.7). The create action routes to
/// [CreateEventScreen], sharing the same bloc so the list re-renders once a
/// [Created] event lands on the watch stream.
class ManageEventsScreen extends StatelessWidget {
  const ManageEventsScreen({
    required this.vendor,
    required this.createBloc,
    required this.createApplicationBloc,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.getStudent,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.rateStudent,
    required this.createStaffCubit,
    super.key,
  });

  /// The vendor whose events are managed (resolved from the session). Its
  /// approval status gates creation (R5.1).
  final Vendor vendor;

  /// Factory for the [StaffCubit] backing the staff-management screen.
  final StaffCubit Function() createStaffCubit;

  /// Factory for the screen's [EventManagementBloc] (typically resolved from
  /// DI).
  final EventManagementBloc Function() createBloc;

  /// Factory for the [ApplicationBloc] backing the per-event applicant review
  /// and attendance-code screens each row opens (R5.3–R5.6).
  final ApplicationBloc Function() createApplicationBloc;

  /// Streams the attendance records for a single event, backing the per-event
  /// attendance view (R5.7).
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;

  /// Streams the applications for a single event; the approved ones are the
  /// enrolled students shown in the attendance view (R5.3, R5.7).
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;

  /// Fetches a single student's full profile by id, backing the applicant
  /// detail view (R5.3, R5.4).
  final Future<Result<Student, Failure>> Function(String uid) getStudent;

  /// Streams the ratings recorded for an event, so the attendance roster can
  /// show/lock already-rated students (R rating).
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;

  /// Streams the ratings a student has received, so the applicant detail can
  /// show the candidate's average rating (R rating).
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

  /// Submits a one-time student rating from the attendance roster (R rating).
  final RateStudentFn rateStudent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventManagementBloc>(
      create: (_) =>
          createBloc()..add(VendorEventsWatchStarted(vendor.uid)),
      child: _ManageEventsView(
        vendor: vendor,
        createApplicationBloc: createApplicationBloc,
        watchEventAttendance: watchEventAttendance,
        watchEventApplications: watchEventApplications,
        getStudent: getStudent,
        watchEventRatings: watchEventRatings,
        watchStudentRatings: watchStudentRatings,
        rateStudent: rateStudent,
        createStaffCubit: createStaffCubit,
      ),
    );
  }
}

class _ManageEventsView extends StatelessWidget {
  const _ManageEventsView({
    required this.vendor,
    required this.createApplicationBloc,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.getStudent,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.rateStudent,
    required this.createStaffCubit,
  });

  final Vendor vendor;
  final StaffCubit Function() createStaffCubit;
  final ApplicationBloc Function() createApplicationBloc;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final RateStudentFn rateStudent;

  void _openCreate(BuildContext context) {
    final EventManagementBloc bloc = context.read<EventManagementBloc>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<EventManagementBloc>.value(
          value: bloc,
          child: CreateEventScreen(vendor: vendor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage events'),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('manage-open-staff'),
              tooltip: 'Staff',
              icon: const Icon(Icons.groups_2_outlined),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => StaffScreen(
                    vendorId: vendor.uid,
                    createCubit: createStaffCubit,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey<String>('manage-open-profile'),
              tooltip: 'My profile',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => VendorProfileScreen(vendor: vendor),
                ),
              ),
            ),
            const LogoutButton(),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Active'),
              Tab(text: 'Closed / Completed'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey<String>('manage-create-event-fab'),
          onPressed: () => _openCreate(context),
          icon: const Icon(Icons.add),
          label: const Text('Create event'),
        ),
        body: BlocConsumer<EventManagementBloc, EventManagementState>(
          listenWhen: (_, EventManagementState state) =>
              state is EventManagementFailure,
          listener: (BuildContext context, EventManagementState state) {
            if (state is EventManagementFailure) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          buildWhen: (_, EventManagementState state) =>
              state is VendorEventsLoaded,
          builder: (BuildContext context, EventManagementState state) {
            if (state is! VendorEventsLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final DateTime now = DateTime.now();
            final List<Event> active = state.events
                .where((Event e) =>
                    effectiveEventStatus(e, now) == EventStatus.active)
                .toList(growable: false);
            final List<Event> past = state.events
                .where((Event e) =>
                    effectiveEventStatus(e, now) != EventStatus.active)
                .toList(growable: false);
            return TabBarView(
              children: <Widget>[
                _EventList(
                  events: active,
                  vendorId: vendor.uid,
                  createApplicationBloc: createApplicationBloc,
                  watchEventAttendance: watchEventAttendance,
                  watchEventApplications: watchEventApplications,
                  getStudent: getStudent,
                  watchEventRatings: watchEventRatings,
                  watchStudentRatings: watchStudentRatings,
                  rateStudent: rateStudent,
                  emptyMessage: 'You have no active events yet.',
                ),
                _EventList(
                  events: past,
                  vendorId: vendor.uid,
                  createApplicationBloc: createApplicationBloc,
                  watchEventAttendance: watchEventAttendance,
                  watchEventApplications: watchEventApplications,
                  getStudent: getStudent,
                  watchEventRatings: watchEventRatings,
                  watchStudentRatings: watchStudentRatings,
                  rateStudent: rateStudent,
                  emptyMessage: 'No closed or completed events yet.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The list of owned events for one status tab, or an empty-state indication.
class _EventList extends StatelessWidget {
  const _EventList({
    required this.events,
    required this.vendorId,
    required this.createApplicationBloc,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.getStudent,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.rateStudent,
    required this.emptyMessage,
  });

  final List<Event> events;
  final String vendorId;
  final ApplicationBloc Function() createApplicationBloc;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final RateStudentFn rateStudent;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) => _EventTile(
        event: events[index],
        vendorId: vendorId,
        createApplicationBloc: createApplicationBloc,
        watchEventAttendance: watchEventAttendance,
        watchEventApplications: watchEventApplications,
        getStudent: getStudent,
        watchEventRatings: watchEventRatings,
        watchStudentRatings: watchStudentRatings,
        rateStudent: rateStudent,
      ),
    );
  }
}

/// A single owned-event row showing its title and status. Tapping it opens the
/// event's applicant list to review/decide applications and see who's coming
/// (R5.3–R5.5); the attendance action opens the per-event attendance view
/// (R5.6, R5.7); the trailing menu transitions the event to another
/// [EventStatus] (R7.5).
class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.vendorId,
    required this.createApplicationBloc,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.getStudent,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.rateStudent,
  });

  final Event event;
  final String vendorId;
  final ApplicationBloc Function() createApplicationBloc;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final RateStudentFn rateStudent;

  void _changeStatus(BuildContext context, EventStatus status) {
    context.read<EventManagementBloc>().add(
          StatusChangeRequested(
            vendorId: vendorId,
            eventId: event.eventId,
            status: status,
          ),
        );
  }

  void _openApplicants(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ApplicationBloc>(
          create: (_) => createApplicationBloc(),
          child: ApplicantListScreen(
            eventId: event.eventId,
            vendorId: vendorId,
            getStudent: getStudent,
            watchStudentRatings: watchStudentRatings,
          ),
        ),
      ),
    );
  }

  void _openAttendance(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ApplicationBloc>(
          create: (_) => createApplicationBloc(),
          child: VendorAttendanceScreen(
            eventId: event.eventId,
            vendorId: vendorId,
            attendanceStream: watchEventAttendance(event.eventId),
            enrolledStream: watchEventApplications(event.eventId),
            ratingsStream: watchEventRatings(event.eventId),
            rateStudent: rateStudent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EventStatus displayStatus =
        effectiveEventStatus(event, DateTime.now());
    // The lifecycle only moves forward (active → closed → completed); a
    // completed event offers no status change.
    final List<EventStatus> transitions =
        allowedEventTransitions(event.status);
    return ListTile(
      key: ValueKey<String>('manage-event-${event.eventId}'),
      isThreeLine: event.approvalStatus != ApprovalStatus.approved,
      leading: const Icon(Icons.event_outlined),
      title: Text(event.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Status: ${displayStatus.wireName} • Slots: ${event.slots} • '
            '₹${event.payPerHead.formatted}',
          ),
          if (event.approvalStatus == ApprovalStatus.pending)
            Text(
              'Awaiting admin approval — not visible to students yet',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            )
          else if (event.approvalStatus == ApprovalStatus.rejected)
            Text(
              'Rejected by admin — not published',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
        ],
      ),
      onTap: () => _openApplicants(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: ValueKey<String>('manage-attendance-${event.eventId}'),
            tooltip: 'Attendance',
            icon: const Icon(Icons.how_to_reg_outlined),
            onPressed: () => _openAttendance(context),
          ),
          if (transitions.isNotEmpty)
            PopupMenuButton<EventStatus>(
              tooltip: 'Change status',
              onSelected: (EventStatus status) =>
                  _changeStatus(context, status),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<EventStatus>>[
                for (final EventStatus status in transitions)
                  PopupMenuItem<EventStatus>(
                    value: status,
                    child: Text('Mark ${status.wireName}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
