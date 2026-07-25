import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../attendance/presentation/screens/check_in_screen.dart';
import '../../../attendance/presentation/screens/check_out_screen.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../ratings/presentation/widgets/star_rating_bar.dart';
import '../../domain/entities/event.dart';
import '../../domain/event_status_policy.dart';
import 'event_detail_screen.dart';

/// The active/inactive classification a student can filter by, derived from the
/// snapshot event date via [isDatePast].
enum _EventActivity { all, active, inactive }

/// The student's unified "My events" screen (R4.2, R4.3, R4.4).
///
/// One card per event the student applied to, combining the application status
/// with the attendance actions: an approved event's card also shows check-in /
/// check-out status and the buttons to record them. Two combinable filters —
/// application status and event active/inactive — narrow the list.
///
/// It joins the student's applications ([StudentApplicationsCubit]) with their
/// attendance records ([AttendanceBloc]'s history stream) by event id; both are
/// watched here and filtered client-side so the filters compose.
class StudentEventsScreen extends StatefulWidget {
  const StudentEventsScreen({
    required this.studentId,
    required this.createStudentApplicationsCubit,
    required this.createAttendanceBloc,
    required this.getEvent,
    required this.ratingsStream,
    super.key,
  });

  /// The id of the signed-in student.
  final String studentId;

  /// Factory for the applications cubit providing every application.
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;

  /// Factory for the attendance bloc backing the history stream and the
  /// check-in / check-out actions.
  final AttendanceBloc Function() createAttendanceBloc;

  /// Fetches a single event by id so tapping a card can open its detail screen
  /// (R8.5).
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

  /// Live stream of the ratings this student has received, so each event card
  /// can show the rating the vendor gave for that event (R rating).
  final Stream<List<RatingEntry>> ratingsStream;

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen> {
  ApplicationStatus? _status;
  _EventActivity _activity = _EventActivity.all;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Application application, DateTime now) {
    if (_status != null && application.status != _status) {
      return false;
    }
    switch (_activity) {
      case _EventActivity.all:
        break;
      case _EventActivity.active:
        final DateTime? date = application.eventDate;
        if (!(date == null || !isDatePast(date, now))) return false;
      case _EventActivity.inactive:
        final DateTime? date = application.eventDate;
        if (!(date != null && isDatePast(date, now))) return false;
    }
    if (_query.isNotEmpty) {
      final String title =
          (application.eventTitle ?? application.eventId).toLowerCase();
      if (!title.contains(_query.toLowerCase())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<StudentApplicationsCubit>(
          create: (_) => widget.createStudentApplicationsCubit()
            ..watch(studentId: widget.studentId),
        ),
        BlocProvider<AttendanceBloc>(
          create: (_) => widget.createAttendanceBloc()
            ..add(HistoryWatchStarted(widget.studentId)),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('My events')),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                onChanged: (String v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search events by name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            _FilterBar(
              status: _status,
              activity: _activity,
              onStatusChanged: (ApplicationStatus? v) =>
                  setState(() => _status = v),
              onActivityChanged: (_EventActivity v) =>
                  setState(() => _activity = v),
            ),
            Expanded(
              child: BlocBuilder<StudentApplicationsCubit,
                  StudentApplicationsState>(
                builder:
                    (BuildContext context, StudentApplicationsState state) {
                  return switch (state) {
                    StudentApplicationsLoading() =>
                      const Center(child: CircularProgressIndicator()),
                    StudentApplicationsFailure(:final String message) =>
                      _Message(
                        icon: Icons.error_outline,
                        text: 'Your events could not be loaded.\n$message',
                      ),
                    StudentApplicationsEmpty() => const _Message(
                        icon: Icons.inbox_outlined,
                        text: 'You have not applied to any events yet.',
                      ),
                    StudentApplicationsLoaded(
                      :final List<Application> applications,
                    ) =>
                      _EventsList(
                        applications: applications,
                        matches: _matches,
                        createAttendanceBloc: widget.createAttendanceBloc,
                        getEvent: widget.getEvent,
                        ratingsStream: widget.ratingsStream,
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The filtered list of merged event cards, joined with attendance records.
class _EventsList extends StatelessWidget {
  const _EventsList({
    required this.applications,
    required this.matches,
    required this.createAttendanceBloc,
    required this.getEvent,
    required this.ratingsStream,
  });

  final List<Application> applications;
  final bool Function(Application application, DateTime now) matches;
  final AttendanceBloc Function() createAttendanceBloc;
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;
  final Stream<List<RatingEntry>> ratingsStream;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (BuildContext context, AttendanceState state) {
        final List<AttendanceRecord> records =
            state is HistoryLoaded ? state.records : const <AttendanceRecord>[];
        final Map<String, AttendanceRecord> byEvent = <String, AttendanceRecord>{
          for (final AttendanceRecord r in records) r.eventId: r,
        };
        final DateTime now = DateTime.now();
        final List<Application> visible = applications
            .where((Application a) => matches(a, now))
            .toList(growable: false);

        if (visible.isEmpty) {
          return const _Message(
            icon: Icons.filter_alt_off_outlined,
            text: 'No events match your filters.',
          );
        }
        return StreamBuilder<List<RatingEntry>>(
          stream: ratingsStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<RatingEntry>> ratingsSnapshot,
          ) {
            final Map<String, RatingEntry> ratingByEvent =
                <String, RatingEntry>{
              for (final RatingEntry r
                  in ratingsSnapshot.data ?? const <RatingEntry>[])
                r.eventId: r,
            };
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final Application application = visible[index];
                return _EventCard(
                  application: application,
                  record: byEvent[application.eventId],
                  createAttendanceBloc: createAttendanceBloc,
                  getEvent: getEvent,
                  rating: ratingByEvent[application.eventId],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// A single merged card: event info + application status + (when approved) the
/// check-in / check-out status and actions.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.application,
    required this.record,
    required this.createAttendanceBloc,
    required this.getEvent,
    required this.rating,
  });

  final Application application;
  final AttendanceRecord? record;
  final AttendanceBloc Function() createAttendanceBloc;
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

  /// The rating the vendor gave this student for this event, if any.
  final RatingEntry? rating;

  bool get _approved => application.status == ApplicationStatus.approved;
  bool get _checkedIn => record?.checkInTime != null;
  bool get _checkedOut => record?.checkOutTime != null;

  /// Fetches this card's event and opens its read-only detail screen, or
  /// surfaces the failure as a snackbar.
  Future<void> _openDetail(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Result<Event, Failure> result = await getEvent(application.eventId);
    result.fold<void>(
      (Event event) => navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      (Failure f) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  void _open(BuildContext context, {required bool checkIn}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<AttendanceBloc>(
          create: (_) => createAttendanceBloc(),
          child: checkIn
              ? CheckInScreen(
                  studentId: application.studentId,
                  eventId: application.eventId,
                )
              : CheckOutScreen(
                  studentId: application.studentId,
                  eventId: application.eventId,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> detailBits = <String>[
      if (application.eventLocation != null) application.eventLocation!,
      if (application.eventPayMinorUnits != null)
        '₹${Money.fromMinorUnits(application.eventPayMinorUnits!, requirePayPerHeadRange: false).formatted}',
      if (application.eventDate != null) _formatDate(application.eventDate!),
    ];

    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.event_available_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      application.eventTitle ?? 'Event ${application.eventId}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: application.status),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            if (detailBits.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  detailBits.join('  •  '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (rating != null) ...<Widget>[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Row(
                  children: <Widget>[
                    Text('Your rating  ', style: theme.textTheme.bodySmall),
                    StarRatingBar(stars: rating!.stars.stars.toDouble()),
                  ],
                ),
              ),
            ],
            if (_approved) ...<Widget>[
              const Divider(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatusLine(
                      label: 'Check-in',
                      done: _checkedIn,
                      time: record?.checkInTime,
                    ),
                  ),
                  if (record?.workingHours != null) ...<Widget>[
                    const SizedBox(width: 8),
                    _HoursPill(hours: record!.workingHours!),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _StatusLine(
                label: 'Check-out',
                done: _checkedOut,
                time: record?.checkOutTime,
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey<String>(
                        'events-checkin-${application.eventId}',
                      ),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Check in'),
                      onPressed: _checkedIn
                          ? null
                          : () => _open(context, checkIn: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: ValueKey<String>(
                        'events-checkout-${application.eventId}',
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Check out'),
                      onPressed: _checkedIn && !_checkedOut
                          ? () => _open(context, checkIn: false)
                          : null,
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  application.status == ApplicationStatus.pending
                      ? 'Awaiting organiser approval — attendance opens once '
                          'approved.'
                      : 'This application was not approved.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// One check-in / check-out status line: icon, label, and time or "Pending".
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.done, this.time});

  final String label;
  final bool done;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color =
        done ? Colors.greenAccent : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: <Widget>[
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            done && time != null ? _formatTime(time!) : 'Pending',
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime t) {
    final DateTime local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
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

/// A small pill showing the computed working hours for a completed record.
class _HoursPill extends StatelessWidget {
  const _HoursPill({required this.hours});

  final double hours;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$hours h',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The two combinable filter rows (status + event activity).
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.activity,
    required this.onStatusChanged,
    required this.onActivityChanged,
  });

  final ApplicationStatus? status;
  final _EventActivity activity;
  final ValueChanged<ApplicationStatus?> onStatusChanged;
  final ValueChanged<_EventActivity> onActivityChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChipRow<ApplicationStatus?>(
            label: 'Status',
            keyPrefix: 'events-filter-status',
            value: status,
            options: const <ApplicationStatus?, String>{
              null: 'All',
              ApplicationStatus.pending: 'Pending',
              ApplicationStatus.approved: 'Approved',
              ApplicationStatus.rejected: 'Rejected',
            },
            onChanged: onStatusChanged,
          ),
          const SizedBox(height: 4),
          _ChipRow<_EventActivity>(
            label: 'Event',
            keyPrefix: 'events-filter-activity',
            value: activity,
            options: const <_EventActivity, String>{
              _EventActivity.all: 'All',
              _EventActivity.active: 'Active',
              _EventActivity.inactive: 'Inactive',
            },
            onChanged: onActivityChanged,
          ),
        ],
      ),
    );
  }
}

/// A single-select, horizontally scrollable row of [ChoiceChip]s.
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String keyPrefix;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final MapEntry<T, String> entry in options.entries) ...
                    <Widget>[
                  ChoiceChip(
                    key: ValueKey<String>(
                      '$keyPrefix-${entry.value.toLowerCase()}',
                    ),
                    label: Text(entry.value),
                    selected: value == entry.key,
                    onSelected: (_) => onChanged(entry.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A centered icon + message for empty / error states.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
