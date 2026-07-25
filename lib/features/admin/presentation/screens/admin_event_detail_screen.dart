import 'package:flutter/material.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/event_finance.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../ratings/presentation/widgets/star_rating_bar.dart';

/// Opens the admin student-detail page for [studentId].
typedef OpenStudent = void Function(BuildContext context, String studentId);

/// Admin drill-down for a single event (R6): the event's details, the money
/// breakdown (total / distributed to students / platform share), and the
/// participant roster showing each student's check-in (login) and check-out
/// (logout) times.
///
/// It joins [enrolledStream] (approved applications = who's enrolled) with
/// [attendanceStream] (their check-in/out records); both come from the existing
/// admin-readable streams, so no new backend surface is needed.
class AdminEventDetailScreen extends StatelessWidget {
  const AdminEventDetailScreen({
    required this.event,
    required this.attendanceStream,
    required this.enrolledStream,
    required this.ratingsStream,
    required this.onOpenStudent,
    required this.vendorName,
    required this.onOpenVendor,
    super.key,
  });

  final Event event;
  final Stream<List<AttendanceRecord>> attendanceStream;
  final Stream<List<Application>> enrolledStream;

  /// Live stream of ratings recorded for this event, shown per participant.
  final Stream<List<RatingEntry>> ratingsStream;

  /// Opens a participant's student-detail page when their row is tapped.
  final OpenStudent onOpenStudent;

  /// Display name of the event's vendor (agency name), resolved by the caller
  /// from the loaded admin lists; falls back to the vendor id when unknown.
  final String vendorName;

  /// Opens the vendor-detail page for this event's vendor when the vendor card
  /// is tapped.
  final void Function(BuildContext context) onOpenVendor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: StreamBuilder<List<Application>>(
        stream: enrolledStream,
        builder: (BuildContext context,
            AsyncSnapshot<List<Application>> appsSnap) {
          final List<Application> enrolled = (appsSnap.data ??
                  const <Application>[])
              .where((Application a) => a.status == ApplicationStatus.approved)
              .toList(growable: false);
          return StreamBuilder<List<AttendanceRecord>>(
            stream: attendanceStream,
            builder: (BuildContext context,
                AsyncSnapshot<List<AttendanceRecord>> attSnap) {
              final List<AttendanceRecord> records =
                  attSnap.data ?? const <AttendanceRecord>[];
              final Map<String, AttendanceRecord> byStudent =
                  <String, AttendanceRecord>{
                for (final AttendanceRecord r in records) r.studentId: r,
              };
              final int completed = records
                  .where((AttendanceRecord r) =>
                      r.checkInTime != null && r.checkOutTime != null)
                  .length;
              final EventFinance finance =
                  computeEventFinance(event, completed);

              return StreamBuilder<List<RatingEntry>>(
                stream: ratingsStream,
                builder: (BuildContext context,
                    AsyncSnapshot<List<RatingEntry>> ratingSnap) {
                  final Map<String, RatingEntry> ratingByStudent =
                      <String, RatingEntry>{
                    for (final RatingEntry r
                        in ratingSnap.data ?? const <RatingEntry>[])
                      r.studentId: r,
                  };
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _VendorCard(
                        vendorName: vendorName,
                        onTap: () => onOpenVendor(context),
                      ),
                      const SizedBox(height: 16),
                      _InfoCard(event: event),
                      const SizedBox(height: 16),
                      _FinanceCard(finance: finance, event: event),
                      const SizedBox(height: 24),
                      Text(
                        'Participants (${enrolled.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (enrolled.isEmpty)
                        Text('No approved participants yet.',
                            style: Theme.of(context).textTheme.bodySmall)
                      else
                        for (final Application a in enrolled)
                          _ParticipantTile(
                            application: a,
                            record: byStudent[a.studentId],
                            rating: ratingByStudent[a.studentId],
                            onOpenStudent: onOpenStudent,
                          ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// A tappable card naming the event's vendor; opens the vendor-detail page.
class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendorName, required this.onTap});

  final String vendorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const Icon(Icons.store_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Vendor', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(vendorName, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _row('Status', event.status.wireName),
            _row('Date', _date(event.date)),
            _row('Time', '${_time(event.startTime)} – ${_time(event.endTime)}'),
            _row('Location', event.location.label),
            _row('Slots', '${event.slots}'),
            _row('Pay per head', '₹${event.payPerHead.formatted}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 120, child: Text(label)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// The money reconciliation card: total budget, distributed to students so far,
/// and the platform's remaining share.
class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.finance, required this.event});

  final EventFinance finance;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Finance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '₹${event.payPerHead.formatted} × ${event.slots} slots · '
              '${finance.completedCount} completed',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            _line(theme, 'Total budget', finance.total, null),
            const SizedBox(height: 8),
            _line(theme, 'Distributed to students', finance.distributed,
                Colors.greenAccent),
            const SizedBox(height: 8),
            _line(theme, 'Platform share', finance.platformShare,
                theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String label, Money value, Color? color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          '₹${value.formatted}',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

/// One participant: name + login (check-in) / logout (check-out) times.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.application,
    required this.record,
    required this.rating,
    required this.onOpenStudent,
  });

  final Application application;
  final AttendanceRecord? record;
  final RatingEntry? rating;
  final OpenStudent onOpenStudent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? login = record?.checkInTime;
    final DateTime? logout = record?.checkOutTime;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onOpenStudent(context, application.studentId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      application.applicantName ?? application.studentId,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (rating != null) ...<Widget>[
                    StarRatingBar(stars: rating!.stars.stars.toDouble()),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _stamp(theme, Icons.login, 'Login', login),
                ),
                Expanded(
                  child: _stamp(theme, Icons.logout, 'Logout', logout),
                ),
              ],
            ),
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
              Text(
                done ? _fmt(t) : '—',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
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
