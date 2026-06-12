import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/event_status.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../domain/entities/event.dart';
import '../bloc/event_management_bloc.dart';
import 'create_event_screen.dart';

/// Vendor-facing "Manage Events" screen listing the events the vendor owns
/// (R5.2) with controls to change each event's status (R7.5) and to create a
/// new event (R5.1, R7.1).
///
/// The screen subscribes to its [EventManagementBloc] via
/// [VendorEventsWatchStarted] and rebuilds whenever the vendor's event set
/// changes, rendering a [VendorEventsLoaded] list or an empty-state indication.
/// Status changes dispatch [StatusChangeRequested]; a rejected change (e.g. a
/// non-owner action, R5.9) surfaces an [EventManagementFailure] as a snackbar.
/// The create action routes to [CreateEventScreen], sharing the same bloc so
/// the list re-renders once a [Created] event lands on the watch stream.
class ManageEventsScreen extends StatelessWidget {
  const ManageEventsScreen({
    required this.vendor,
    required this.createBloc,
    super.key,
  });

  /// The vendor whose events are managed (resolved from the session). Its
  /// approval status gates creation (R5.1).
  final Vendor vendor;

  /// Factory for the screen's [EventManagementBloc] (typically resolved from
  /// DI).
  final EventManagementBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventManagementBloc>(
      create: (_) =>
          createBloc()..add(VendorEventsWatchStarted(vendor.uid)),
      child: _ManageEventsView(vendor: vendor),
    );
  }
}

class _ManageEventsView extends StatelessWidget {
  const _ManageEventsView({required this.vendor});

  final Vendor vendor;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Manage events')),
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
          if (state.events.isEmpty) {
            return const Center(
              child: Text('You have not created any events yet.'),
            );
          }
          return ListView.separated(
            itemCount: state.events.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) => _EventTile(
              event: state.events[index],
              vendorId: vendor.uid,
            ),
          );
        },
      ),
    );
  }
}

/// A single owned-event row showing its title and status, with a menu to
/// transition the event to another [EventStatus] (R7.5).
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.vendorId});

  final Event event;
  final String vendorId;

  void _changeStatus(BuildContext context, EventStatus status) {
    context.read<EventManagementBloc>().add(
          StatusChangeRequested(
            vendorId: vendorId,
            eventId: event.eventId,
            status: status,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey<String>('manage-event-${event.eventId}'),
      leading: const Icon(Icons.event_outlined),
      title: Text(event.title),
      subtitle: Text(
        'Status: ${event.status.wireName} • Slots: ${event.slots} • '
        '₹${event.payPerHead.formatted}',
      ),
      trailing: PopupMenuButton<EventStatus>(
        tooltip: 'Change status',
        onSelected: (EventStatus status) => _changeStatus(context, status),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<EventStatus>>[
          for (final EventStatus status in EventStatus.values)
            if (status != event.status)
              PopupMenuItem<EventStatus>(
                value: status,
                child: Text('Mark ${status.wireName}'),
              ),
        ],
      ),
    );
  }
}
