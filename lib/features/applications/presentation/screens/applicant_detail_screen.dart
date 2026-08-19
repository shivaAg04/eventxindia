import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/student_stats.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../ratings/domain/rating_stats.dart';
import '../../../ratings/presentation/widgets/star_rating_bar.dart';
import '../../domain/entities/application.dart';

/// Vendor-facing detail view for a single applicant (R5.3, R5.4).
///
/// Loads the applicant's full [Student] profile via [getStudent] and shows
/// **every** field — name, city, gender, age/date of birth, height, and member
/// since — **except the mobile number**, which is deliberately never shown to a
/// vendor to protect the student's contact detail (privacy). It also shows the
/// application status and the event the application is for.
///
/// Alongside the profile it shows the candidate's **track record** — how many
/// events they have been approved for platform-wide and how many of those they
/// completed attendance for — read from the trusted `StudentStatsService`. A
/// vendor cannot compute that themselves: security rules scope
/// application/attendance reads to their own events.
///
/// While the profile loads, or if it cannot be read (e.g. the record predates
/// vendor read access), it falls back to the basic snapshot the vendor already
/// holds on the [Application] so the vendor can still identify the candidate.
class ApplicantDetailScreen extends StatelessWidget {
  const ApplicantDetailScreen({
    required this.application,
    required this.getStudent,
    required this.ratingsStream,
    required this.statsStream,
    super.key,
  });

  final Application application;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;

  /// Live stream of the ratings this applicant has received, so the vendor sees
  /// the candidate's overall average rating while reviewing them.
  final Stream<List<RatingEntry>> ratingsStream;

  /// Live stream of this applicant's trusted track-record counters (events
  /// approved for, attendance completed).
  final Stream<StudentStats> statsStream;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applicant')),
      body: FutureBuilder<Result<Student, Failure>>(
        future: getStudent(application.studentId),
        builder: (
          BuildContext context,
          AsyncSnapshot<Result<Student, Failure>> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final Student? student = snapshot.data?.valueOrNull;
          return _DetailBody(
            application: application,
            student: student,
            ratingsStream: ratingsStream,
            statsStream: statsStream,
          );
        },
      ),
    );
  }
}

/// Renders the applicant detail from the loaded [student] (full profile) with a
/// fallback to the [application] snapshot when the profile is unavailable.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.application,
    required this.student,
    required this.ratingsStream,
    required this.statsStream,
  });

  final Application application;
  final Student? student;
  final Stream<List<RatingEntry>> ratingsStream;
  final Stream<StudentStats> statsStream;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = student?.fullName ??
        application.applicantName ??
        application.studentId;
    final String? city = student?.city ?? application.applicantCity;
    final String? photo = student?.profilePhotoPath;

    // Every student field the vendor is allowed to see — the phone is omitted.
    final List<MapEntry<String, String>> profileRows =
        <MapEntry<String, String>>[
      MapEntry<String, String>('Name', name),
      if (city != null && city.isNotEmpty)
        MapEntry<String, String>('City', city),
      if (student != null)
        MapEntry<String, String>('Gender', student!.gender.wireName),
      if (student != null)
        MapEntry<String, String>(
          'Age',
          '${_age(student!.dateOfBirth)} years',
        ),
      if (student != null)
        MapEntry<String, String>(
          'Date of birth',
          _date(student!.dateOfBirth),
        ),
      if (student != null)
        MapEntry<String, String>('Height', '${student!.heightCm} cm'),
      if (student != null)
        MapEntry<String, String>(
          'Member since',
          _date(student!.createdAt),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 32,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? NetworkImage(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(_initial(name))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: theme.textTheme.titleLarge),
                  if (city != null && city.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(city, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            _StatusBadge(status: application.status),
          ],
        ),
        const SizedBox(height: 16),
        _RatingCard(ratingsStream: ratingsStream),
        const SizedBox(height: 16),
        _TrackRecordCard(statsStream: statsStream),
        const SizedBox(height: 16),
        _DetailCard(title: 'Student', rows: profileRows),
        const SizedBox(height: 16),
        _DetailCard(
          title: 'Application',
          rows: <MapEntry<String, String>>[
            MapEntry<String, String>('Status', application.status.wireName),
            MapEntry<String, String>(
              'Applied on',
              _date(application.createdAt),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailCard(
          title: 'Event',
          rows: <MapEntry<String, String>>[
            MapEntry<String, String>(
              'Title',
              application.eventTitle ?? application.eventId,
            ),
            if (application.eventDate != null)
              MapEntry<String, String>('Date', _date(application.eventDate!)),
            if (application.eventLocation != null)
              MapEntry<String, String>(
                'Location',
                application.eventLocation!,
              ),
            if (application.eventPayMinorUnits != null)
              MapEntry<String, String>(
                'Pay per head',
                '₹${Money.fromMinorUnits(application.eventPayMinorUnits!, requirePayPerHeadRange: false).formatted}',
              ),
          ],
        ),
      ],
    );
  }

  String _initial(String name) {
    final String trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  /// Whole years between [dob] and today (calendar-based).
  static int _age(DateTime dob) {
    final DateTime now = DateTime.now();
    int years = now.year - dob.year;
    final bool beforeBirthday = now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day);
    if (beforeBirthday) years -= 1;
    return years < 0 ? 0 : years;
  }

  static String _date(DateTime d) {
    final DateTime l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }
}

/// A card showing the applicant's overall average rating (mean of all event
/// ratings received), streamed live so it reflects new ratings.
class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.ratingsStream});

  final Stream<List<RatingEntry>> ratingsStream;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<RatingEntry>>(
          stream: ratingsStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<RatingEntry>> snapshot,
          ) {
            final List<RatingEntry> ratings =
                snapshot.data ?? const <RatingEntry>[];
            final double? average = averageStars(ratings);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Average rating', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    if (average == null)
                      Text(
                        'No ratings yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      StarRatingLabel(
                        stars: average,
                        size: 20,
                        count: ratings.length,
                      ),
                  ],
                ),
                Text(
                  formatAverage(average),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A card showing the applicant's platform-wide track record: how many events
/// they were approved for and how many they completed attendance for, plus the
/// share of approved events they actually saw through.
///
/// Both counters come from the trusted `StudentStatsService`
/// (`studentStats/{studentId}`, maintained by Cloud Functions) — the vendor
/// cannot derive them, since per-document rules scope application/attendance
/// reads to their own events. Only the counts are exposed here, never the
/// underlying events, times, or locations.
///
/// Until the aggregator has written anything for this student the stream yields
/// zeroed counters, which render as an explicit "No event history yet" rather
/// than a misleading 0%.
class _TrackRecordCard extends StatelessWidget {
  const _TrackRecordCard({required this.statsStream});

  final Stream<StudentStats> statsStream;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<StudentStats>(
          stream: statsStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<StudentStats> snapshot,
          ) {
            final StudentStats? stats = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Track record', style: theme.textTheme.titleMedium),
                const Divider(height: 20),
                // A read failure (offline, or rules denying the counters) must
                // not leave the card spinning forever: say so, and let the
                // vendor judge the applicant on the rest of the screen.
                if (snapshot.hasError)
                  Text(
                    'History unavailable right now.',
                    key: const ValueKey<String>('stat-error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (stats == null)
                  Text(
                    'Loading history…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (stats.isEmpty)
                  Text(
                    'No event history yet — this is their first event.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else ...<Widget>[
                  // IntrinsicHeight bounds the row so `stretch` can give all
                  // three tiles a common height; without it the row sits in an
                  // unbounded ListView and `stretch` forces infinite height.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _CountTile(
                          key: const ValueKey<String>('stat-events'),
                          icon: Icons.event_note_rounded,
                          color: const Color(0xFF3B82F6),
                          value: '${stats.eventsParticipated}',
                          label: 'Events participated',
                        ),
                        const SizedBox(width: 8),
                        _CountTile(
                          key: const ValueKey<String>('stat-attendance'),
                          icon: Icons.task_alt_rounded,
                          color: AppColors.success,
                          value: '${stats.attendanceCompleted}',
                          label: 'Attendance marked',
                        ),
                        const SizedBox(width: 8),
                        _CountTile(
                          key: const ValueKey<String>('stat-rate'),
                          icon: Icons.track_changes_rounded,
                          color: AppColors.accent,
                          value: _rate(stats),
                          label: 'Attendance rate',
                        ),
                      ],
                    ),
                  ),
                  if (stats.eventsParticipated > 0) ...<Widget>[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: stats.attendanceCompleted /
                            stats.eventsParticipated,
                        minHeight: 8,
                        backgroundColor: AppColors.fieldFill,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _summary(stats),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The share of approved events the student actually completed, as a whole
  /// percentage — the same figure the student's own profile shows as
  /// "Attendance", and computed with the same formula so the two agree.
  ///
  /// Renders as an em dash when there are no approved events, since a rate with
  /// no denominator would be meaningless rather than 0%.
  static String _rate(StudentStats stats) {
    if (stats.eventsParticipated == 0) return '—';
    return '${_ratePercent(stats)}%';
  }

  static int _ratePercent(StudentStats stats) =>
      ((stats.attendanceCompleted / stats.eventsParticipated) * 100).round();

  /// A one-line reading of the two counters, e.g.
  /// "Completed attendance for 11 of 12 events on record (92%)."
  ///
  /// Says "on record" rather than naming the denominator's source, so the line
  /// stays accurate whichever `StudentStatsService` implementation is wired.
  /// The percentage is dropped when the denominator is zero, so it never divides
  /// by zero or implies a rate that has no denominator.
  static String _summary(StudentStats stats) {
    if (stats.eventsParticipated == 0) {
      return 'Completed attendance for ${stats.attendanceCompleted} '
          'event(s).';
    }
    return 'Completed attendance for ${stats.attendanceCompleted} of '
        '${stats.eventsParticipated} events on record '
        '(${_ratePercent(stats)}%).';
  }
}

/// One tinted stat tile — icon badge, big number, caption — used by
/// [_TrackRecordCard].
///
/// Deliberately mirrors the stat cards on the student's own profile so the same
/// numbers read the same way on both sides of the app. Expands to fill its share
/// of the row, and the value is wrapped in a [FittedBox] so a wide value (e.g.
/// "100%") shrinks rather than overflowing a narrow tile.
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card rendering a list of label/value rows.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            const Divider(height: 20),
            for (final MapEntry<String, String> row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 120, child: Text(row.key)),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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

/// A compact coloured chip for the application status.
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
