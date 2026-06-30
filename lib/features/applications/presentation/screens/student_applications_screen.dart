import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
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

/// The list of a student's applications, each showing the event by name plus
/// the snapshot detail (location, pay, date) and the application status.
class _ApplicationList extends StatelessWidget {
  const _ApplicationList({required this.applications});

  final List<Application> applications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: applications.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        return _ApplicationTile(application: applications[index]);
      },
    );
  }
}

/// A single application row: the event title, its detail line, and a status
/// chip. Falls back to the event id for records saved before the event
/// snapshot existed.
class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final Application application;

  @override
  Widget build(BuildContext context) {
    final List<String> detailBits = <String>[
      if (application.eventLocation != null) application.eventLocation!,
      if (application.eventPayMinorUnits != null)
        '₹${Money.fromMinorUnits(application.eventPayMinorUnits!, requirePayPerHeadRange: false).formatted}',
      if (application.eventDate != null) _formatDate(application.eventDate!),
    ];
    final String? detail = detailBits.isEmpty ? null : detailBits.join(' • ');

    return ListTile(
      key: ValueKey<String>('application-${application.applicationId}'),
      isThreeLine: detail != null,
      leading: const Icon(Icons.event_available_outlined),
      title: Text(application.eventTitle ?? 'Event ${application.eventId}'),
      subtitle: Text(
        detail == null
            ? 'Status: ${application.status.wireName}'
            : '$detail\nStatus: ${application.status.wireName}',
      ),
      trailing: _StatusBadge(status: application.status),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// A compact coloured chip for an application's status.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      ApplicationStatus.approved => Colors.greenAccent,
      ApplicationStatus.rejected => Theme.of(context).colorScheme.error,
      ApplicationStatus.pending => Colors.amberAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.wireName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
