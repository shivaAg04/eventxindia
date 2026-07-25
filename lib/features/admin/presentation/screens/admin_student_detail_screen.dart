import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../events/domain/event_status_policy.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../ratings/domain/rating_stats.dart';
import '../../../ratings/presentation/widgets/star_rating_bar.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/domain/entities/withdrawal_request.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';

/// Opens the admin event-detail page for [eventId].
typedef OpenEvent = void Function(BuildContext context, String eventId);

/// The active/inactive classification for the joined-events event filter,
/// derived from the snapshot event date via [isDatePast].
enum _EventActivity { all, active, inactive }

/// Admin drill-down for a single student (R6): a profile header plus two tabs —
/// **Wallet** (balance + transactions, read-only) and **Joined events** (their
/// applications with a status filter and, where present, the check-in /
/// check-out detail). Event names/cards open the admin event-detail page via
/// [onOpenEvent].
class AdminStudentDetailScreen extends StatefulWidget {
  const AdminStudentDetailScreen({
    required this.student,
    required this.applicationsStream,
    required this.attendanceStream,
    required this.ratingsStream,
    required this.createWalletCubit,
    required this.onOpenEvent,
    super.key,
  });

  final Student student;
  final Stream<List<Application>> applicationsStream;
  final Stream<List<AttendanceRecord>> attendanceStream;

  /// Live stream of the ratings this student has received, backing the header
  /// average and the per-event rating on each joined-event card.
  final Stream<List<RatingEntry>> ratingsStream;
  final WalletCubit Function() createWalletCubit;
  final OpenEvent onOpenEvent;

  @override
  State<AdminStudentDetailScreen> createState() =>
      _AdminStudentDetailScreenState();
}

class _AdminStudentDetailScreenState extends State<AdminStudentDetailScreen> {
  // Applications are subscribed once here and shared with both tabs (event
  // names for the wallet credits, and the list for the joined-events tab).
  List<Application> _apps = const <Application>[];
  List<RatingEntry> _ratings = const <RatingEntry>[];
  StreamSubscription<List<Application>>? _sub;
  StreamSubscription<List<RatingEntry>>? _ratingsSub;

  @override
  void initState() {
    super.initState();
    _sub = widget.applicationsStream.listen((List<Application> apps) {
      if (mounted) setState(() => _apps = apps);
    });
    _ratingsSub = widget.ratingsStream.listen((List<RatingEntry> ratings) {
      if (mounted) setState(() => _ratings = ratings);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ratingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> eventNames = <String, String>{
      for (final Application a in _apps)
        if (a.eventTitle != null) a.eventId: a.eventTitle!,
    };
    final Map<String, RatingEntry> ratingByEvent = <String, RatingEntry>{
      for (final RatingEntry r in _ratings) r.eventId: r,
    };
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.student.fullName)),
        body: Column(
          children: <Widget>[
            _ProfileHeader(
              student: widget.student,
              average: averageStars(_ratings),
              ratingCount: _ratings.length,
            ),
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Wallet'),
                Tab(text: 'Joined events'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _WalletTab(
                    studentId: widget.student.uid,
                    createWalletCubit: widget.createWalletCubit,
                    eventNames: eventNames,
                    onOpenEvent: widget.onOpenEvent,
                  ),
                  _JoinedEventsTab(
                    applications: _apps,
                    attendanceStream: widget.attendanceStream,
                    ratingByEvent: ratingByEvent,
                    onOpenEvent: widget.onOpenEvent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A richer profile card: avatar with initials, name + phone, and a chip grid.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.student,
    required this.average,
    required this.ratingCount,
  });

  final Student student;
  final double? average;
  final int ratingCount;

  String get _initials {
    final List<String> parts = student.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.glassCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  height: 52,
                  width: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Color(0xFF0A0E1F),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(student.fullName,
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(student.phone.e164,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      if (average == null)
                        Text('No ratings yet',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted))
                      else
                        StarRatingLabel(
                          stars: average!,
                          count: ratingCount,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _chip(theme, Icons.location_city_outlined, student.city),
                _chip(theme, Icons.wc_outlined, student.gender.wireName),
                _chip(theme, Icons.height, '${student.heightCm} cm'),
                _chip(theme, Icons.cake_outlined, _date(student.dateOfBirth)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// --- Wallet tab -------------------------------------------------------------

class _WalletTab extends StatelessWidget {
  const _WalletTab({
    required this.studentId,
    required this.createWalletCubit,
    required this.eventNames,
    required this.onOpenEvent,
  });

  final String studentId;
  final WalletCubit Function() createWalletCubit;
  final Map<String, String> eventNames;
  final OpenEvent onOpenEvent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WalletCubit>(
      create: (_) => createWalletCubit()..watch(studentId),
      child: BlocBuilder<WalletCubit, WalletState>(
        builder: (BuildContext context, WalletState state) {
          return switch (state) {
            WalletLoading() =>
              const Center(child: CircularProgressIndicator()),
            WalletFailure(:final String message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Wallet could not be loaded.\n$message',
                      textAlign: TextAlign.center),
                ),
              ),
            WalletLoaded(:final Wallet wallet) => _WalletView(
                wallet: wallet,
                eventNames: eventNames,
                onOpenEvent: onOpenEvent,
              ),
          };
        },
      ),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView({
    required this.wallet,
    required this.eventNames,
    required this.onOpenEvent,
  });

  final Wallet wallet;
  final Map<String, String> eventNames;
  final OpenEvent onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<MapEntry<String, Money>> credits =
        wallet.creditsPerEvent.entries.toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Available balance', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Text('₹${wallet.available.formatted}',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Divider(height: 24),
                Row(
                  children: <Widget>[
                    _stat(theme, 'Earned', wallet.credited),
                    _stat(theme, 'On hold', wallet.pendingTotal),
                    _stat(theme, 'Paid out', wallet.approvedTotal),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Withdrawal requests', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (wallet.withdrawals.isEmpty)
          Text('No withdrawal requests.', style: theme.textTheme.bodySmall)
        else
          for (final WithdrawalRequest w in wallet.withdrawals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.north_east),
              title: Text('-₹${w.amount.formatted}'),
              subtitle: Text('Requested ${_date(w.createdAt)}'),
              trailing: Text(w.status.wireName),
            ),
        const SizedBox(height: 20),
        Text('Event credits', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (credits.isEmpty)
          Text('No event credits.', style: theme.textTheme.bodySmall)
        else
          for (final MapEntry<String, Money> c in credits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.south_west, color: Colors.greenAccent),
              title: Text(eventNames[c.key] ?? c.key),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('+₹${c.value.formatted}',
                      style: const TextStyle(color: Colors.greenAccent)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              onTap: () => onOpenEvent(context, c.key),
            ),
      ],
    );
  }

  Widget _stat(ThemeData theme, String label, Money value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text('₹${value.formatted}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  static String _date(DateTime d) {
    final DateTime l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }
}

// --- Joined events tab ------------------------------------------------------

class _JoinedEventsTab extends StatefulWidget {
  const _JoinedEventsTab({
    required this.applications,
    required this.attendanceStream,
    required this.ratingByEvent,
    required this.onOpenEvent,
  });

  final List<Application> applications;
  final Stream<List<AttendanceRecord>> attendanceStream;
  final Map<String, RatingEntry> ratingByEvent;
  final OpenEvent onOpenEvent;

  @override
  State<_JoinedEventsTab> createState() => _JoinedEventsTabState();
}

class _JoinedEventsTabState extends State<_JoinedEventsTab> {
  ApplicationStatus? _status;
  _EventActivity _activity = _EventActivity.all;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Application a, DateTime now) {
    if (_status != null && a.status != _status) {
      return false;
    }
    switch (_activity) {
      case _EventActivity.all:
        break;
      case _EventActivity.active:
        final DateTime? d = a.eventDate;
        if (!(d == null || !isDatePast(d, now))) return false;
      case _EventActivity.inactive:
        final DateTime? d = a.eventDate;
        if (!(d != null && isDatePast(d, now))) return false;
    }
    if (_query.isNotEmpty) {
      final String title = (a.eventTitle ?? a.eventId).toLowerCase();
      if (!title.contains(_query.toLowerCase())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceRecord>>(
      stream: widget.attendanceStream,
      builder: (BuildContext context,
          AsyncSnapshot<List<AttendanceRecord>> attSnap) {
        final Map<String, AttendanceRecord> byEvent =
            <String, AttendanceRecord>{
          for (final AttendanceRecord r
              in attSnap.data ?? const <AttendanceRecord>[])
            r.eventId: r,
        };
        final DateTime now = DateTime.now();
        final List<Application> visible = widget.applications
            .where((Application a) => _matches(a, now))
            .toList(growable: false);
        return Column(
          children: <Widget>[
            _SearchField(
              controller: _search,
              hint: 'Search events by name',
              onChanged: (String v) => setState(() => _query = v),
            ),
            _ChipRow<ApplicationStatus?>(
              label: 'Status',
              keyPrefix: 'joined-status',
              value: _status,
              options: const <ApplicationStatus?, String>{
                null: 'All',
                ApplicationStatus.pending: 'Pending',
                ApplicationStatus.approved: 'Approved',
                ApplicationStatus.rejected: 'Rejected',
              },
              onChanged: (ApplicationStatus? v) => setState(() => _status = v),
            ),
            _ChipRow<_EventActivity>(
              label: 'Event',
              keyPrefix: 'joined-activity',
              value: _activity,
              options: const <_EventActivity, String>{
                _EventActivity.all: 'All',
                _EventActivity.active: 'Active',
                _EventActivity.inactive: 'Inactive',
              },
              onChanged: (_EventActivity v) => setState(() => _activity = v),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No events match your filters.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int i) =>
                          _JoinedEventCard(
                        application: visible[i],
                        record: byEvent[visible[i].eventId],
                        rating: widget.ratingByEvent[visible[i].eventId],
                        onOpenEvent: widget.onOpenEvent,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// A compact search field used above filterable lists.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// A single-select, horizontally scrollable row of [ChoiceChip]s bound to [T].
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
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
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

class _JoinedEventCard extends StatelessWidget {
  const _JoinedEventCard({
    required this.application,
    required this.record,
    required this.rating,
    required this.onOpenEvent,
  });

  final Application application;
  final AttendanceRecord? record;
  final RatingEntry? rating;
  final OpenEvent onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? checkIn = record?.checkInTime;
    final DateTime? checkOut = record?.checkOutTime;
    final bool hasAttendance = checkIn != null || checkOut != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onOpenEvent(context, application.eventId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(application.eventTitle ?? application.eventId,
                        style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(width: 8),
                  if (rating != null) ...<Widget>[
                    StarRatingBar(stars: rating!.stars.stars.toDouble()),
                    const SizedBox(width: 8),
                  ],
                  Text(application.status.wireName,
                      style: theme.textTheme.labelMedium),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              if (application.eventPayMinorUnits != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  '₹${Money.fromMinorUnits(application.eventPayMinorUnits!, requirePayPerHeadRange: false).formatted}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              if (hasAttendance)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _stamp(theme, Icons.login, 'Check-in', checkIn),
                    ),
                    Expanded(
                      child:
                          _stamp(theme, Icons.logout, 'Check-out', checkOut),
                    ),
                  ],
                )
              else
                Text('No attendance recorded.',
                    style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stamp(ThemeData theme, IconData icon, String label, DateTime? t) {
    final bool done = t != null;
    final Color color =
        done ? Colors.greenAccent : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: theme.textTheme.bodySmall),
              Text(done ? _fmt(t) : '—',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime t) {
    final DateTime l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
  }
}
