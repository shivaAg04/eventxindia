import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/presentation/bloc/application_bloc.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../domain/entities/event.dart';
import '../../domain/event_filters.dart';
import '../../domain/event_status_policy.dart';
import '../bloc/event_discovery_bloc.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';

/// Student dashboard "Active events" list (R4.1, R4.7).
///
/// Owns its [EventDiscoveryBloc] (built from the injected [createBloc] factory
/// and started with [DiscoveryStarted], which streams the active event set via
/// `WatchActiveEvents`). On top of the streamed set the student can search by
/// title/location, sort by date or pay, and filter to a date range — all
/// applied client-side through the pure [searchActiveEvents] / [sortEvents] /
/// [filterByDateRange] selectors. The screen never talks to a use case or
/// repository directly.
class StudentActiveEventsScreen extends StatelessWidget {
  const StudentActiveEventsScreen({
    required this.createBloc,
    required this.studentId,
    required this.createApplicationBloc,
    required this.createStudentApplicationsCubit,
    super.key,
  });

  /// Factory for the screen's [EventDiscoveryBloc] (typically resolved from DI).
  final EventDiscoveryBloc Function() createBloc;

  /// The signed-in student's id, threaded into the detail/apply flow (R8.6).
  final String studentId;

  /// Factory for the [ApplicationBloc] backing the apply action on the detail
  /// screen each card opens (R8.6).
  final ApplicationBloc Function() createApplicationBloc;

  /// Factory for the [StudentApplicationsCubit] used to learn which events the
  /// student has already applied to, so cards and the detail screen can reflect
  /// that persistently (R9.2).
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<EventDiscoveryBloc>(
          create: (_) => createBloc()..add(const DiscoveryStarted()),
        ),
        BlocProvider<StudentApplicationsCubit>(
          create: (_) =>
              createStudentApplicationsCubit()..watch(studentId: studentId),
        ),
      ],
      child: _ActiveEventsView(
        studentId: studentId,
        createApplicationBloc: createApplicationBloc,
      ),
    );
  }
}

/// Stateful body holding the search query, sort order, and date-range filter,
/// and applying them to the streamed active-event set.
class _ActiveEventsView extends StatefulWidget {
  const _ActiveEventsView({
    required this.studentId,
    required this.createApplicationBloc,
  });

  final String studentId;
  final ApplicationBloc Function() createApplicationBloc;

  @override
  State<_ActiveEventsView> createState() => _ActiveEventsViewState();
}

class _ActiveEventsViewState extends State<_ActiveEventsView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  EventSort _sort = EventSort.dateAsc;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Applies past-event exclusion → search → date-range → sort to the streamed
  /// [events], so events whose date has already passed are not shown as
  /// joinable.
  List<Event> _visible(List<Event> events) {
    final DateTime now = DateTime.now();
    final List<Event> upcoming = events
        .where((Event e) => !isEventPast(e, now))
        .toList(growable: false);
    final List<Event> searched = searchActiveEvents(_query, upcoming);
    final List<Event> ranged = filterByDateRange(
      searched,
      start: _range?.start,
      end: _range?.end,
    );
    return sortEvents(ranged, _sort);
  }

  void _openDetail(Event event, {required bool applied}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(
          event: event,
          studentId: widget.studentId,
          createApplicationBloc: widget.createApplicationBloc,
          alreadyApplied: applied,
        ),
      ),
    );
  }

  /// The set of event ids the student has already applied to (any status), from
  /// the ambient [StudentApplicationsCubit]. An existing application — approved,
  /// pending, or rejected — blocks re-applying, so all count as "applied".
  Set<String> _appliedIds(StudentApplicationsState state) =>
      state is StudentApplicationsLoaded
          ? state.applications
              .map((Application a) => a.eventId)
              .toSet()
          : const <String>{};

  Future<void> _pickRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> appliedIds =
        _appliedIds(context.watch<StudentApplicationsCubit>().state);
    return Scaffold(
      appBar: AppBar(title: const Text('Active events')),
      body: Column(
        children: <Widget>[
          _Controls(
            search: _search,
            sort: _sort,
            range: _range,
            onQueryChanged: (String value) => setState(() => _query = value),
            onSortChanged: (EventSort value) => setState(() => _sort = value),
            onPickRange: _pickRange,
            onClearRange: () => setState(() => _range = null),
          ),
          Expanded(
            child: BlocBuilder<EventDiscoveryBloc, EventDiscoveryState>(
              buildWhen: (_, EventDiscoveryState state) => state is! EventDetail,
              builder: (BuildContext context, EventDiscoveryState state) {
                return switch (state) {
                  EventsLoaded(:final List<Event> events) =>
                    _buildList(_visible(events), appliedIds),
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
        ],
      ),
    );
  }

  Widget _buildList(List<Event> events, Set<String> appliedIds) {
    if (events.isEmpty) {
      return const StudentDashboardMessage(
        key: ValueKey<String>('active-events-no-match'),
        icon: Icons.search_off_outlined,
        message: 'No events match your search or filters.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Event event = events[index];
        final bool applied = appliedIds.contains(event.eventId);
        return EventCard(
          key: ValueKey<String>('active-event-${event.eventId}'),
          event: event,
          applied: applied,
          onTap: () => _openDetail(event, applied: applied),
        );
      },
    );
  }
}

/// The search field plus the sort and date-range controls shown above the list.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.search,
    required this.sort,
    required this.range,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onPickRange,
    required this.onClearRange,
  });

  final TextEditingController search;
  final EventSort sort;
  final DateTimeRange? range;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EventSort> onSortChanged;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;

  static const Map<EventSort, String> _sortLabels = <EventSort, String>{
    EventSort.dateAsc: 'Date: soonest',
    EventSort.dateDesc: 'Date: latest',
    EventSort.payAsc: 'Pay: low to high',
    EventSort.payDesc: 'Pay: high to low',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('active-search-field'),
            controller: search,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by title or location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        search.clear();
                        onQueryChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PopupMenuButton<EventSort>(
                  initialValue: sort,
                  onSelected: onSortChanged,
                  itemBuilder: (BuildContext context) => <
                      PopupMenuEntry<EventSort>>[
                    for (final MapEntry<EventSort, String> e
                        in _sortLabels.entries)
                      PopupMenuItem<EventSort>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                  ],
                  child: _PillButton(
                    icon: Icons.swap_vert,
                    label: _sortLabels[sort]!,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: range == null
                    ? _PillButton(
                        icon: Icons.date_range_outlined,
                        label: 'Date range',
                        onTap: onPickRange,
                      )
                    : _PillButton(
                        icon: Icons.event_available_outlined,
                        label: _formatRange(range!),
                        onTap: onPickRange,
                        onTrailingTap: onClearRange,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatRange(DateTimeRange r) =>
      '${_d(r.start)} – ${_d(r.end)}';

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// A compact, tappable pill used for the sort and date-range controls.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.onTrailingTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onTrailingTap != null)
                GestureDetector(
                  onTap: onTrailingTap,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
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
