import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/application_status.dart';
import '../../../../core/value_objects/money.dart';
import '../../../profile/domain/entities/student.dart';
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
/// While the profile loads, or if it cannot be read (e.g. the record predates
/// vendor read access), it falls back to the basic snapshot the vendor already
/// holds on the [Application] so the vendor can still identify the candidate.
class ApplicantDetailScreen extends StatelessWidget {
  const ApplicantDetailScreen({
    required this.application,
    required this.getStudent,
    required this.ratingsStream,
    super.key,
  });

  final Application application;
  final Future<Result<Student, Failure>> Function(String uid) getStudent;

  /// Live stream of the ratings this applicant has received, so the vendor sees
  /// the candidate's overall average rating while reviewing them.
  final Stream<List<RatingEntry>> ratingsStream;

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
  });

  final Application application;
  final Student? student;
  final Stream<List<RatingEntry>> ratingsStream;

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
