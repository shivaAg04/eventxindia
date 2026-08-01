import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../../core/widgets/dashboard_header.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../attendance/presentation/screens/check_in_screen.dart';
import '../../../attendance/presentation/screens/check_out_screen.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../ratings/presentation/widgets/star_rating_bar.dart';
import '../../domain/entities/event.dart';
import '../../domain/event_finance.dart';
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
        // The header + filter scroll away; the search bar pins to the top and
        // then the list scrolls beneath it.
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool _) => <Widget>[
            SliverToBoxAdapter(
              child: DashboardHeader(
                title: 'My',
                titleAccent: 'events',
                subtitle: 'Manage all your event schedules',
                mascot: Image.asset(
                  'assets/images/my_event.png',
                  width: 190,
                  height: 150,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
            // Search bar + filter card both pin to the top together.
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedControlsDelegate(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _SearchField(
                        controller: _search,
                        query: _query,
                        onChanged: (String v) => setState(() => _query = v),
                        onClear: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
                    _FilterCard(
                      status: _status,
                      activity: _activity,
                      onStatusChanged: (ApplicationStatus? v) =>
                          setState(() => _status = v),
                      onActivityChanged: (_EventActivity v) =>
                          setState(() => _activity = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: BlocBuilder<StudentApplicationsCubit,
              StudentApplicationsState>(
            builder: (BuildContext context, StudentApplicationsState state) {
              return switch (state) {
                StudentApplicationsLoading() =>
                  const Center(child: CircularProgressIndicator()),
                StudentApplicationsFailure(:final String message) => _Message(
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

  /// The card's accent (left stripe + icon tile) keyed to the status.
  Color get _accent => switch (application.status) {
        ApplicationStatus.approved => AppColors.accent,
        ApplicationStatus.pending => AppColors.amber,
        ApplicationStatus.rejected => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> detailBits = <String>[
      if (application.eventLocation != null) application.eventLocation!,
      if (application.eventPayMinorUnits != null)
        '₹${Money.fromMinorUnits(splitCommission(application.eventPayMinorUnits!, application.eventCommissionPercent ?? 0).studentNetMinor, requirePayPerHeadRange: false).formatted}',
      if (application.eventDate != null) _formatDate(application.eventDate!),
    ];

    return Card(
      child: InkWell(
        onTap: () => _openDetail(context),
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Left status stripe.
              Container(width: 5, color: _accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.event_note_rounded,
                                color: _accent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        application.eventTitle ??
                                            'Event ${application.eventId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusBadge(status: application.status),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.chevron_right,
                                        size: 18, color: AppColors.textMuted),
                                  ],
                                ),
                                if (detailBits.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 3),
                                  Text(
                                    detailBits.join('  •  '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (rating != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Text('Your rating  ',
                                style: theme.textTheme.bodySmall),
                            StarRatingBar(
                                stars: rating!.stars.stars.toDouble()),
                          ],
                        ),
                      ],
                      if (_approved) ...<Widget>[
                        const Divider(height: 22),
                        _StatusLine(
                          label: 'Check-in',
                          icon: Icons.check_circle_outline,
                          done: _checkedIn,
                          time: record?.checkInTime,
                        ),
                        const SizedBox(height: 8),
                        _StatusLine(
                          label: 'Check-out',
                          icon: Icons.schedule_rounded,
                          done: _checkedOut,
                          time: record?.checkOutTime,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                key: ValueKey<String>(
                                    'events-checkin-${application.eventId}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                      color: AppColors.primary, width: 1.3),
                                  minimumSize: const Size.fromHeight(48),
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
                              child: OutlinedButton.icon(
                                key: ValueKey<String>(
                                    'events-checkout-${application.eventId}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(
                                      color: AppColors.accent, width: 1.3),
                                  minimumSize: const Size.fromHeight(48),
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
                        Text(
                          application.status == ApplicationStatus.pending
                              ? 'Awaiting organiser approval — attendance '
                                  'opens once approved.'
                              : 'This application was not approved.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
  const _StatusLine({
    required this.label,
    required this.icon,
    required this.done,
    this.time,
  });

  final String label;
  final IconData icon;
  final bool done;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = done ? AppColors.success : AppColors.accent;
    return Row(
      children: <Widget>[
        Icon(done ? Icons.check_circle : icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          done && time != null ? _formatTime(time!) : 'Pending',
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime t) {
    final DateTime local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// A compact solid-tint pill for an application's status.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      ApplicationStatus.approved => AppColors.success,
      ApplicationStatus.rejected => AppColors.danger,
      ApplicationStatus.pending => AppColors.amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
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

/// Pins the search field + filter card to the top of the scroll view. Carries
/// an opaque lavender background (matching the canvas) so the scrolling list
/// never shows through behind the pinned controls.
class _PinnedControlsDelegate extends SliverPersistentHeaderDelegate {
  _PinnedControlsDelegate({required this.child});

  final Widget child;

  // Search field (~72) + filter card (~112), with a small buffer.
  static const double _height = 192;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedControlsDelegate oldDelegate) => true;
}

/// The white, rounded search field with the accent filter (tune) button.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // One large white pill with a big purple search icon (same as Active
    // events); no side filter button here — the Status/Event card is below.
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x1A101828),
      borderRadius: BorderRadius.circular(32),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          hintText: 'Search events by name',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 18, right: 10),
            child: Icon(Icons.search, color: AppColors.accent, size: 26),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear), onPressed: onClear),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// The white card holding the Status and Event filter pill rows.
class _FilterCard extends StatelessWidget {
  const _FilterCard({
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          _FilterRow(
            label: 'Status',
            children: <Widget>[
              _FilterPill(
                label: 'All',
                selected: status == null,
                onTap: () => onStatusChanged(null),
              ),
              _FilterPill(
                label: 'Pending',
                selected: status == ApplicationStatus.pending,
                onTap: () => onStatusChanged(ApplicationStatus.pending),
              ),
              _FilterPill(
                label: 'Approved',
                selected: status == ApplicationStatus.approved,
                onTap: () => onStatusChanged(ApplicationStatus.approved),
              ),
              _FilterPill(
                label: 'Rejected',
                selected: status == ApplicationStatus.rejected,
                onTap: () => onStatusChanged(ApplicationStatus.rejected),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FilterRow(
            label: 'Event',
            children: <Widget>[
              _FilterPill(
                label: 'All',
                selected: activity == _EventActivity.all,
                onTap: () => onActivityChanged(_EventActivity.all),
              ),
              _FilterPill(
                label: 'Active',
                selected: activity == _EventActivity.active,
                onTap: () => onActivityChanged(_EventActivity.active),
              ),
              _FilterPill(
                label: 'Inactive',
                selected: activity == _EventActivity.inactive,
                onTap: () => onActivityChanged(_EventActivity.inactive),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A label + a wrapping set of filter pills.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single filter pill: brand-tinted with a check when selected; otherwise a
/// clean neutral-grey pill.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.14)
          : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(Icons.check_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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
