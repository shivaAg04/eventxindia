import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../applications/presentation/bloc/application_bloc.dart';
import '../../../applications/presentation/bloc/application_event.dart';
import '../../../applications/presentation/bloc/application_state.dart';
import '../../domain/entities/event.dart';

/// Detail view for a single [Event] (R8.5, R8.6).
///
/// Renders every field a student needs to evaluate a gig: the title,
/// description, status, date, start/end times, location label, available
/// slots, and the pay-per-head amount.
///
/// When opened for a signed-in student ([studentId] and [createApplicationBloc]
/// supplied) and the event is still [EventStatus.active], a persistent
/// "Apply to join" action is shown (R8.6): tapping it submits the application
/// via an [ApplicationBloc], reporting success, an already-applied duplicate
/// (R9.2), or a failure. Opened without those (e.g. a read-only preview) it is
/// a pure presentation widget that owns no bloc.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    required this.event,
    this.studentId,
    this.createApplicationBloc,
    super.key,
  });

  /// The event whose detail is displayed.
  final Event event;

  /// The signed-in student's id, when the detail is opened for a student who
  /// can apply; `null` for a read-only view.
  final String? studentId;

  /// Factory for the [ApplicationBloc] backing the apply action; `null` for a
  /// read-only view.
  final ApplicationBloc Function()? createApplicationBloc;

  /// Whether this is a student context viewing an event still open for
  /// applications (R8.6, R8.7).
  bool get _isStudentContext =>
      studentId != null &&
      createApplicationBloc != null &&
      event.status == EventStatus.active;

  /// Whether the live apply action (which needs an [ApplicationBloc]) should be
  /// offered: a student context on an event that still has free seats.
  bool get _canApply => _isStudentContext && !event.isFull;

  @override
  Widget build(BuildContext context) {
    final Widget? bottomBar = !_isStudentContext
        ? null
        : event.isFull
            ? const _FullBar()
            : _ApplyBar(studentId: studentId!, eventId: event.eventId);

    final Scaffold scaffold = Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      bottomNavigationBar: bottomBar,
      body: _body(context),
    );
    // Only the live apply bar needs the bloc; the read-only / full bars don't.
    if (!_canApply) {
      return scaffold;
    }
    return BlocProvider<ApplicationBloc>(
      create: (_) => createApplicationBloc!(),
      child: scaffold,
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            event.title,
            key: const ValueKey<String>('detail-title'),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          _StatusChip(status: event.status),
          const SizedBox(height: 16),
          Text(
            event.description,
            key: const ValueKey<String>('detail-description'),
            style: theme.textTheme.bodyMedium,
          ),
          const Divider(height: 32),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _formatDate(event.date),
          ),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Time',
            value: '${_formatTime(event.startTime)} - '
                '${_formatTime(event.endTime)}',
          ),
          _DetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: event.location.label,
          ),
          _DetailRow(
            icon: Icons.event_seat_outlined,
            label: 'Seats',
            value: event.isFull
                ? 'Full — all ${event.slots} slots filled'
                : '${event.seatsRemaining} of ${event.slots} available',
          ),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Pay per head',
            value: '₹${event.payPerHead.formatted}',
          ),
        ],
      );
  }

  /// Formats a [date] as `YYYY-MM-DD` without depending on locale data.
  static String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Formats a [time] as `HH:MM` (24-hour) without depending on locale data.
  static String _formatTime(DateTime time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// A disabled bottom bar shown to a student when the event has no seats left.
class _FullBar extends StatelessWidget {
  const _FullBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.event_busy),
          label: const Text('Event is full'),
        ),
      ),
    );
  }
}

/// The persistent bottom bar carrying the student's "Apply to join" action
/// (R8.6).
///
/// Reads the ambient [ApplicationBloc] provided by [EventDetailScreen]. The
/// button submits an [ApplyRequested]; while in flight it shows a spinner, and
/// once the application exists — freshly created ([Applied]) or already present
/// ([DuplicateApplication], R9.2) — it settles into a disabled "Applied" state.
/// Outcomes are also echoed in a snackbar.
class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.studentId, required this.eventId});

  final String studentId;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: BlocConsumer<ApplicationBloc, ApplicationState>(
          listenWhen: (_, ApplicationState state) =>
              state is Applied ||
              state is DuplicateApplication ||
              state is ApplicationFailure,
          listener: (BuildContext context, ApplicationState state) {
            final String? message = switch (state) {
              Applied() => 'Application submitted — pending vendor approval.',
              DuplicateApplication() =>
                'You have already applied to this event.',
              ApplicationFailure(:final Failure failure) => failure.message,
              _ => null,
            };
            if (message != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }
          },
          builder: (BuildContext context, ApplicationState state) {
            final bool applied =
                state is Applied || state is DuplicateApplication;
            final bool busy = state is Applying;
            return FilledButton.icon(
              key: const ValueKey<String>('detail-apply'),
              onPressed: applied || busy
                  ? null
                  : () => context.read<ApplicationBloc>().add(
                        ApplyRequested(studentId: studentId, eventId: eventId),
                      ),
              icon: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(applied ? Icons.check_circle : Icons.how_to_reg),
              label: Text(
                busy
                    ? 'Applying…'
                    : applied
                        ? 'Applied'
                        : 'Apply to join',
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A labelled icon row used for each scalar event field in the detail view.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small chip indicating the event's lifecycle [status].
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      key: const ValueKey<String>('detail-status'),
      label: Text(status.wireName),
      visualDensity: VisualDensity.compact,
    );
  }
}
