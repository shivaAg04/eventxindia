import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/event.dart';
import '../bloc/event_discovery_bloc.dart';
import 'event_detail_screen.dart';

/// Student-facing event discovery screen with inline search (R8.1–R8.5).
///
/// Owns its [EventDiscoveryBloc] (built from the injected [createBloc] factory
/// and started with [DiscoveryStarted]) and renders the active-event list. A
/// search field dispatches [SearchQueryChanged] as the student types; the bloc
/// re-filters the cached active set case-insensitively against title and
/// location (R8.3). The body switches on the emitted state:
/// * [EventsLoaded] → the matching list, each tappable to open its detail
///   (R8.1, R8.5).
/// * [EventsEmpty] → an empty-state indication that no active events exist
///   (R8.2).
/// * [SearchNoResults] → a no-results indication for the current query (R8.4).
/// * [EventDiscoveryFailure] → an error indication.
///
/// Tapping an event dispatches [EventSelected]; when the bloc emits
/// [EventDetail] the screen pushes [EventDetailScreen]. The screen never talks
/// to a use case or repository directly.
class EventDiscoveryScreen extends StatelessWidget {
  const EventDiscoveryScreen({required this.createBloc, super.key});

  /// Factory for the screen's [EventDiscoveryBloc] (typically resolved from DI).
  final EventDiscoveryBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventDiscoveryBloc>(
      create: (_) => createBloc()..add(const DiscoveryStarted()),
      child: const _EventDiscoveryView(),
    );
  }
}

class _EventDiscoveryView extends StatefulWidget {
  const _EventDiscoveryView();

  @override
  State<_EventDiscoveryView> createState() => _EventDiscoveryViewState();
}

class _EventDiscoveryViewState extends State<_EventDiscoveryView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    context.read<EventDiscoveryBloc>().add(SearchQueryChanged(query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover events')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey<String>('discovery-search-field'),
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search by title or location',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: BlocConsumer<EventDiscoveryBloc, EventDiscoveryState>(
              listenWhen: (_, state) => state is EventDetail,
              listener: (context, state) {
                if (state is EventDetail) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => EventDetailScreen(event: state.event),
                    ),
                  );
                }
              },
              buildWhen: (_, state) => state is! EventDetail,
              builder: (context, state) {
                return switch (state) {
                  EventsLoaded(:final events) =>
                    _EventList(events: events),
                  EventsEmpty() => const _MessageView(
                      icon: Icons.event_busy_outlined,
                      message: 'No active events are available.',
                    ),
                  SearchNoResults(:final query) => _MessageView(
                      icon: Icons.search_off_outlined,
                      message: 'No active events match "$query".',
                    ),
                  EventDiscoveryFailure(:final message) => _MessageView(
                      icon: Icons.error_outline,
                      message: message,
                    ),
                  _ => const Center(child: CircularProgressIndicator()),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The list of active (optionally filtered) events; each row opens its detail.
class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          key: ValueKey<String>('discovery-event-${event.eventId}'),
          leading: const Icon(Icons.event_outlined),
          title: Text(event.title),
          subtitle: Text(event.location.label),
          trailing: Text('₹${event.payPerHead.formatted}'),
          onTap: () => context
              .read<EventDiscoveryBloc>()
              .add(EventSelected(event.eventId)),
        );
      },
    );
  }
}

/// A centered icon + message used for empty, no-results, and error states.
class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message});

  final IconData icon;
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
