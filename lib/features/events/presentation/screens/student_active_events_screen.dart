import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/event.dart';
import '../bloc/event_discovery_bloc.dart';
import '../widgets/event_card.dart';

/// Student dashboard "Active events" list (R4.1, R4.7).
///
/// Owns its [EventDiscoveryBloc] (built from the injected [createBloc] factory
/// and started with [DiscoveryStarted], which streams the active event set via
/// `WatchActiveEvents`). The body switches on the emitted state:
/// * [EventsLoaded] → the active-event list (R4.1).
/// * [EventsEmpty] → an empty-state indication that no active events exist
///   (R4.1).
/// * [EventDiscoveryFailure] → a read-failure indication that the data could
///   not be loaded (R4.7).
///
/// Unlike the discovery screen this dashboard list has no search field; it
/// simply surfaces the current active events. The screen never talks to a use
/// case or repository directly.
class StudentActiveEventsScreen extends StatelessWidget {
  const StudentActiveEventsScreen({required this.createBloc, super.key});

  /// Factory for the screen's [EventDiscoveryBloc] (typically resolved from DI).
  final EventDiscoveryBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventDiscoveryBloc>(
      create: (_) => createBloc()..add(const DiscoveryStarted()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Active events')),
        body: BlocBuilder<EventDiscoveryBloc, EventDiscoveryState>(
          buildWhen: (_, EventDiscoveryState state) => state is! EventDetail,
          builder: (BuildContext context, EventDiscoveryState state) {
            return switch (state) {
              EventsLoaded(:final List<Event> events) =>
                _ActiveEventList(events: events),
              EventsEmpty() => const StudentDashboardMessage(
                  key: ValueKey<String>('active-events-empty'),
                  icon: Icons.event_busy_outlined,
                  message: 'No active events are available.',
                ),
              SearchNoResults() => const StudentDashboardMessage(
                  icon: Icons.event_busy_outlined,
                  message: 'No active events are available.',
                ),
              EventDiscoveryFailure(:final String message) =>
                StudentDashboardMessage(
                  key: const ValueKey<String>('active-events-error'),
                  icon: Icons.error_outline,
                  message: 'Active events could not be loaded.\n$message',
                ),
              _ => const Center(child: CircularProgressIndicator()),
            };
          },
        ),
      ),
    );
  }
}

/// The list of active events shown on the dashboard.
class _ActiveEventList extends StatelessWidget {
  const _ActiveEventList({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Event event = events[index];
        return EventCard(
          key: ValueKey<String>('active-event-${event.eventId}'),
          event: event,
        );
      },
    );
  }
}

/// A centered icon + message used across the student dashboard for empty-state
/// and read-failure indications (R4.1–R4.7).
class StudentDashboardMessage extends StatelessWidget {
  const StudentDashboardMessage({
    required this.icon,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
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
