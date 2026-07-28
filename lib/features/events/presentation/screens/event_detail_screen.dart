import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
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
    this.alreadyApplied = false,
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

  /// Whether the student has already applied to this event (from a previous
  /// session), so the apply action starts in its disabled "Applied" state
  /// rather than only reacting to an in-session tap (R9.2).
  final bool alreadyApplied;

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
            : _ApplyBar(
                studentId: studentId!,
                eventId: event.eventId,
                alreadyApplied: alreadyApplied,
              );

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
    final bool full = event.isFull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: <Widget>[
        // Hero image slot — the events carry no image, so a branded banner.
        Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Icon(Icons.groups_rounded, color: Colors.white, size: 56),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                event.title,
                key: const ValueKey<String>('detail-title'),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              full ? 'Full' : '${event.seatsRemaining} Slots Left',
              style: TextStyle(
                color: full ? AppColors.danger : AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const Icon(Icons.place_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                event.location.label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
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
                icon: Icons.payments_outlined,
                label: 'You earn (per head)',
                value: '₹${event.studentNetPayPerHead.formatted}',
                highlight: true,
              ),
              _DetailRow(
                icon: Icons.event_seat_outlined,
                label: 'Seats',
                value: full
                    ? 'All ${event.slots} filled'
                    : '${event.seatsRemaining} of ${event.slots}',
                last: true,
              ),
            ],
          ),
        ),
        if (event.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            event.description,
            key: const ValueKey<String>('detail-description'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats a [date] as e.g. `25 May 2024`.
  static String _formatDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// Formats a [time] as 12-hour `10:00 AM`.
  static String _formatTime(DateTime time) {
    final int h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final String m = time.minute.toString().padLeft(2, '0');
    final String ap = time.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
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
  const _ApplyBar({
    required this.studentId,
    required this.eventId,
    this.alreadyApplied = false,
  });

  final String studentId;
  final String eventId;

  /// Seeds the disabled "Applied" state for a student who applied previously.
  final bool alreadyApplied;

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
            final bool applied = alreadyApplied ||
                state is Applied ||
                state is DuplicateApplication;
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
                        : 'Apply Now',
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A labelled icon row used for each scalar event field in the detail view:
/// a tinted icon, the label on the left, and the value on the right.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Renders the value in the brand colour (used for the pay row).
  final bool highlight;

  /// Suppresses the bottom divider on the final row.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
