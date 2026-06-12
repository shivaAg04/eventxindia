import 'package:flutter/material.dart';

import '../../../../core/value_objects/event_status.dart';
import '../../domain/entities/event.dart';

/// Read-only detail view for a single discovered [Event] (R8.5).
///
/// Renders every field a student needs to evaluate a gig: the title,
/// description, status, date, start/end times, location label, available
/// slots, and the pay-per-head amount. It is a pure presentation widget driven
/// entirely by the [event] handed to it by [EventDiscoveryScreen] when the
/// `EventDiscoveryBloc` emits `EventDetail`; it owns no bloc and performs no
/// I/O.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({required this.event, super.key});

  /// The event whose detail is displayed.
  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: ListView(
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
            icon: Icons.people_outline,
            label: 'Slots',
            value: '${event.slots}',
          ),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Pay per head',
            value: '₹${event.payPerHead.formatted}',
          ),
        ],
      ),
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
