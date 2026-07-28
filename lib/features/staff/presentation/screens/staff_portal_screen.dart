import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/value_objects/rating.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/presentation/bloc/application_bloc.dart';
import '../../../applications/presentation/screens/applicant_list_screen.dart';
import '../../../applications/presentation/screens/vendor_attendance_screen.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../domain/entities/staff_member.dart';

/// Submits a one-time student rating (mirrors the vendor-side signature).
typedef StaffRateStudentFn = Future<Result<RatingEntry, Failure>> Function({
  required String eventId,
  required String studentId,
  required String vendorId,
  required Rating stars,
});

/// The scoped portal a staff member lands on after login.
///
/// It resolves the staff member's context (parent vendor + role) from their
/// verified phone, then lists that vendor's events. Each event exposes only the
/// actions the staff role permits: **Applicants** (approve/reject) when the
/// role can manage applicants, and **Attendance** when it can manage attendance.
/// A staff member never creates events, manages other staff, or edits the
/// vendor profile.
class StaffPortalScreen extends StatelessWidget {
  const StaffPortalScreen({
    required this.staffPhone,
    required this.findStaffByPhone,
    required this.watchVendorEvents,
    required this.createApplicationBloc,
    required this.getStudent,
    required this.watchStudentRatings,
    required this.watchEventApplications,
    required this.watchEventAttendance,
    required this.watchEventRatings,
    required this.rateStudent,
    super.key,
  });

  /// The signed-in staff member's phone (E.164), used to resolve their context.
  final String staffPhone;
  final Future<Result<StaffMember?, Failure>> Function(String phoneE164)
      findStaffByPhone;
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;
  final ApplicationBloc Function() createApplicationBloc;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final StaffRateStudentFn rateStudent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My work'),
        actions: const <Widget>[LogoutButton()],
      ),
      body: FutureBuilder<Result<StaffMember?, Failure>>(
        future: findStaffByPhone(staffPhone),
        builder: (BuildContext context,
            AsyncSnapshot<Result<StaffMember?, Failure>> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final StaffMember? staff = snap.data?.valueOrNull;
          if (staff == null) {
            return const _Message(
              icon: Icons.badge_outlined,
              text: 'No staff access found for your number.\n'
                  'Ask the vendor to add you as staff.',
            );
          }
          return _EventsList(
            staff: staff,
            watchVendorEvents: watchVendorEvents,
            createApplicationBloc: createApplicationBloc,
            getStudent: getStudent,
            watchStudentRatings: watchStudentRatings,
            watchEventApplications: watchEventApplications,
            watchEventAttendance: watchEventAttendance,
            watchEventRatings: watchEventRatings,
            rateStudent: rateStudent,
          );
        },
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({
    required this.staff,
    required this.watchVendorEvents,
    required this.createApplicationBloc,
    required this.getStudent,
    required this.watchStudentRatings,
    required this.watchEventApplications,
    required this.watchEventAttendance,
    required this.watchEventRatings,
    required this.rateStudent,
  });

  final StaffMember staff;
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;
  final ApplicationBloc Function() createApplicationBloc;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final StaffRateStudentFn rateStudent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        // A banner showing who they're helping and what they can do.
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Staff · ${staff.role.label}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(
                'You can ${_can(staff)} for this vendor\'s events.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Event>>(
            stream: watchVendorEvents(staff.vendorId),
            builder: (BuildContext context,
                AsyncSnapshot<List<Event>> snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<Event> events = snap.data!;
              if (events.isEmpty) {
                return const _Message(
                  icon: Icons.event_busy_outlined,
                  text: 'This vendor has no events yet.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: events.length,
                itemBuilder: (_, int i) => _EventCard(
                  event: events[i],
                  staff: staff,
                  createApplicationBloc: createApplicationBloc,
                  getStudent: getStudent,
                  watchStudentRatings: watchStudentRatings,
                  watchEventApplications: watchEventApplications,
                  watchEventAttendance: watchEventAttendance,
                  watchEventRatings: watchEventRatings,
                  rateStudent: rateStudent,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _can(StaffMember s) {
    final List<String> parts = <String>[
      if (s.role.canManageApplicants) 'review applicants',
      if (s.role.canManageAttendance) 'manage attendance',
    ];
    return parts.join(' and ');
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.staff,
    required this.createApplicationBloc,
    required this.getStudent,
    required this.watchStudentRatings,
    required this.watchEventApplications,
    required this.watchEventAttendance,
    required this.watchEventRatings,
    required this.rateStudent,
  });

  final Event event;
  final StaffMember staff;
  final ApplicationBloc Function() createApplicationBloc;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final StaffRateStudentFn rateStudent;

  void _openApplicants(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => BlocProvider<ApplicationBloc>(
        create: (_) => createApplicationBloc(),
        child: ApplicantListScreen(
          eventId: event.eventId,
          vendorId: staff.vendorId,
          getStudent: getStudent,
          watchStudentRatings: watchStudentRatings,
        ),
      ),
    ));
  }

  void _openAttendance(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => BlocProvider<ApplicationBloc>(
        create: (_) => createApplicationBloc(),
        child: VendorAttendanceScreen(
          eventId: event.eventId,
          vendorId: staff.vendorId,
          attendanceStream: watchEventAttendance(event.eventId),
          enrolledStream: watchEventApplications(event.eventId),
          ratingsStream: watchEventRatings(event.eventId),
          rateStudent: rateStudent,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(event.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Event details',
                  icon: const Icon(Icons.info_outline, size: 20),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${event.slots} slots · ₹${event.payPerHead.formatted} per head',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (staff.role.canManageApplicants)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey<String>('staff-applicants-${event.eventId}'),
                      onPressed: () => _openApplicants(context),
                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                      label: const Text('Applicants'),
                    ),
                  ),
                if (staff.role.canManageApplicants &&
                    staff.role.canManageAttendance)
                  const SizedBox(width: 10),
                if (staff.role.canManageAttendance)
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey<String>('staff-attendance-${event.eventId}'),
                      onPressed: () => _openAttendance(context),
                      icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                      label: const Text('Attendance'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
