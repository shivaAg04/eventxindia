import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
import '../../../events/domain/entities/event.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

/// Admin monitoring screen showing the student, vendor, and event lists, with
/// vendor approval/rejection actions (R6.1–R6.6, R6.9).
///
/// Tabs render the registered students (R6.4), the vendors each with their
/// approval status and approve/reject controls for pending vendors (R6.1,
/// R6.2, R6.5), and the events each with their lifecycle status (R6.6). When
/// every list is empty the bloc emits [EmptyState] and the screen shows an
/// empty-state indication (R6.9). A failed approve/reject surfaces as a
/// [AdminActionFailure] snackbar conveying that the vendor is not Pending
/// (R6.3).
///
/// The screen owns its [AdminBloc], built from the injected [createBloc]
/// factory and started with [ListsWatchStarted]; it never talks to a use case
/// or repository directly.
class AdminListsScreen extends StatelessWidget {
  const AdminListsScreen({required this.createBloc, super.key});

  /// Factory for the screen's [AdminBloc] (typically resolved from DI).
  final AdminBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminBloc>(
      create: (_) => createBloc()..add(const ListsWatchStarted()),
      child: const _AdminListsView(),
    );
  }
}

class _AdminListsView extends StatelessWidget {
  const _AdminListsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: const <Widget>[LogoutButton()],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Students'),
              Tab(text: 'Vendors'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: BlocConsumer<AdminBloc, AdminState>(
          listenWhen: (_, state) => state is AdminActionFailure,
          listener: (context, state) {
            if (state is AdminActionFailure) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          buildWhen: (_, state) =>
              state is ListsLoaded ||
              state is EmptyState ||
              state is AdminInitial,
          builder: (context, state) {
            return switch (state) {
              ListsLoaded(
                :final students,
                :final vendors,
                :final events,
              ) =>
                TabBarView(
                  children: <Widget>[
                    _StudentList(students: students),
                    _VendorList(vendors: vendors),
                    _EventList(events: events),
                  ],
                ),
              EmptyState() => const _EmptyView(
                  message: 'No records are available yet.',
                ),
              _ => const Center(child: CircularProgressIndicator()),
            };
          },
        ),
      ),
    );
  }
}

/// The registered student list (R6.4) with an empty-state indication (R6.9).
class _StudentList extends StatelessWidget {
  const _StudentList({required this.students});

  final List<Student> students;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const _EmptyView(message: 'No students are registered.');
    }
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          key: ValueKey<String>('student-${student.uid}'),
          leading: const Icon(Icons.person_outline),
          title: Text(student.fullName),
          subtitle: Text(student.city),
        );
      },
    );
  }
}

/// The registered vendor list with approval status and approve/reject controls
/// for pending vendors (R6.1, R6.2, R6.5) and an empty-state indication (R6.9).
class _VendorList extends StatelessWidget {
  const _VendorList({required this.vendors});

  final List<Vendor> vendors;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return const _EmptyView(message: 'No vendors are registered.');
    }
    return ListView.builder(
      itemCount: vendors.length,
      itemBuilder: (context, index) {
        final vendor = vendors[index];
        final isPending = vendor.approvalStatus == ApprovalStatus.pending;
        return ListTile(
          key: ValueKey<String>('vendor-${vendor.uid}'),
          leading: const Icon(Icons.store_outlined),
          title: Text(vendor.agencyName),
          subtitle: Text(
            '${vendor.fullName} · ${vendor.approvalStatus.wireName}',
          ),
          trailing: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      key: ValueKey<String>('approve-${vendor.uid}'),
                      tooltip: 'Approve',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => context
                          .read<AdminBloc>()
                          .add(VendorApproveRequested(vendor.uid)),
                    ),
                    IconButton(
                      key: ValueKey<String>('reject-${vendor.uid}'),
                      tooltip: 'Reject',
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () => context
                          .read<AdminBloc>()
                          .add(VendorRejectRequested(vendor.uid)),
                    ),
                  ],
                )
              : _StatusChip(label: vendor.approvalStatus.wireName),
        );
      },
    );
  }
}

/// The event list, each event with its lifecycle status (R6.6) and an
/// empty-state indication (R6.9).
class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyView(message: 'No events exist.');
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          key: ValueKey<String>('event-${event.eventId}'),
          leading: const Icon(Icons.event_outlined),
          title: Text(event.title),
          trailing: _StatusChip(label: event.status.wireName),
        );
      },
    );
  }
}

/// A small status label used for vendor approval and event statuses.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

/// An empty-state indication conveying that no records are available (R6.9).
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inbox_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
