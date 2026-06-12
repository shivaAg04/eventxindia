import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../../events/presentation/screens/student_active_events_screen.dart'
    show StudentDashboardMessage;
import '../../domain/entities/application.dart';
import '../bloc/student_applications_cubit.dart';

/// Student dashboard list of the events a student has applied to, optionally
/// scoped to a single application status (R4.2, R4.3, R4.7).
///
/// Owns its [StudentApplicationsCubit] (built from the injected [createCubit]
/// factory and started with [StudentApplicationsCubit.watch] for [studentId]).
/// Passing [statusFilter] = `null` renders every submitted application
/// (R4.2); passing [ApplicationStatus.approved] renders only approved ones
/// (R4.3). The body switches on the emitted state:
/// * [StudentApplicationsLoaded] → the matching applications.
/// * [StudentApplicationsEmpty] → an empty-state indication.
/// * [StudentApplicationsFailure] → a read-failure indication (R4.7).
///
/// The screen never talks to a use case or repository directly.
class StudentApplicationsScreen extends StatelessWidget {
  const StudentApplicationsScreen({
    required this.studentId,
    required this.createCubit,
    this.statusFilter,
    this.title,
    super.key,
  });

  /// The id of the student whose applications are shown.
  final String studentId;

  /// Factory for the screen's [StudentApplicationsCubit] (resolved from DI).
  final StudentApplicationsCubit Function() createCubit;

  /// When non-null, only applications with this status are shown (R4.3).
  final ApplicationStatus? statusFilter;

  /// Optional app-bar title; defaults based on [statusFilter].
  final String? title;

  @override
  Widget build(BuildContext context) {
    final String resolvedTitle = title ??
        (statusFilter == ApplicationStatus.approved
            ? 'Approved events'
            : 'Applied events');

    return BlocProvider<StudentApplicationsCubit>(
      create: (_) => createCubit()
        ..watch(studentId: studentId, statusFilter: statusFilter),
      child: Scaffold(
        appBar: AppBar(title: Text(resolvedTitle)),
        body: BlocBuilder<StudentApplicationsCubit, StudentApplicationsState>(
          builder: (BuildContext context, StudentApplicationsState state) {
            return switch (state) {
              StudentApplicationsLoaded(
                :final List<Application> applications,
              ) =>
                _ApplicationList(applications: applications),
              StudentApplicationsEmpty() => StudentDashboardMessage(
                  key: const ValueKey<String>('student-applications-empty'),
                  icon: Icons.inbox_outlined,
                  message: statusFilter == ApplicationStatus.approved
                      ? 'You have no approved events yet.'
                      : 'You have not applied to any events yet.',
                ),
              StudentApplicationsFailure(:final String message) =>
                StudentDashboardMessage(
                  key: const ValueKey<String>('student-applications-error'),
                  icon: Icons.error_outline,
                  message: 'Your applications could not be loaded.\n$message',
                ),
              StudentApplicationsLoading() =>
                const Center(child: CircularProgressIndicator()),
            };
          },
        ),
      ),
    );
  }
}

/// The list of a student's applications, each showing the event id and status.
class _ApplicationList extends StatelessWidget {
  const _ApplicationList({required this.applications});

  final List<Application> applications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: applications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final Application application = applications[index];
        return ListTile(
          key: ValueKey<String>('application-${application.applicationId}'),
          leading: const Icon(Icons.event_available_outlined),
          title: Text('Event ${application.eventId}'),
          subtitle: Text('Status: ${application.status.wireName}'),
        );
      },
    );
  }
}
