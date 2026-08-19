import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/application_status.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/presentation/screens/applicant_detail_screen.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/student_stats.dart';
import 'package:eventxindia/features/ratings/domain/entities/rating_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The vendor-facing track record on the applicant detail screen (R5.3, R5.4):
/// how many events the applicant was approved for and how many they completed
/// attendance for, read from the trusted `StudentStatsService`.
void main() {
  final DateTime now = DateTime(2026, 8, 20);

  Application application() => Application(
        applicationId: 'e1_s1',
        eventId: 'e1',
        studentId: 's1',
        status: ApplicationStatus.pending,
        createdAt: now,
        updatedAt: now,
        applicantName: 'Asha Rao',
        applicantCity: 'Pune',
      );

  Future<void> pumpDetail(
    WidgetTester tester,
    StudentStats stats,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: ApplicantDetailScreen(
        application: application(),
        // The profile read is irrelevant here; fall back to the snapshot.
        getStudent: (String uid) async =>
            const Result<Student, Failure>.err(NotFoundFailure()),
        ratingsStream:
            Stream<List<RatingEntry>>.value(const <RatingEntry>[]),
        statsStream: Stream<StudentStats>.value(stats),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both counters and the completion summary', (
    WidgetTester tester,
  ) async {
    await pumpDetail(
      tester,
      StudentStats(
        studentId: 's1',
        eventsParticipated: 12,
        attendanceCompleted: 11,
      ),
    );

    expect(find.text('Track record'), findsOneWidget);
    expect(find.text('Events participated'), findsOneWidget);
    expect(find.text('Attendance marked'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('stat-events')),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('stat-attendance')),
        matching: find.text('11'),
      ),
      findsOneWidget,
    );
    expect(find.text('Attendance rate'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('stat-rate')),
        matching: find.text('92%'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Completed attendance for 11 of 12 events on record (92%).'),
      findsOneWidget,
    );
  });

  testWidgets('lays the three tiles out without overflow at phone width', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDetail(
      tester,
      StudentStats(
        studentId: 's1',
        eventsParticipated: 1,
        attendanceCompleted: 1,
      ),
    );

    // A RenderFlex overflow (the labels colliding) surfaces here as an
    // exception; the labels must each stay inside their own tile.
    expect(tester.takeException(), isNull);
    for (final String key in <String>[
      'stat-events',
      'stat-attendance',
      'stat-rate',
    ]) {
      final Rect tile = tester.getRect(find.byKey(ValueKey<String>(key)));
      expect(tile.width, lessThan(360));
      expect(tile.left, greaterThanOrEqualTo(0));
    }
    // Tiles must not overlap each other.
    final Rect first = tester.getRect(
      find.byKey(const ValueKey<String>('stat-events')),
    );
    final Rect second = tester.getRect(
      find.byKey(const ValueKey<String>('stat-attendance')),
    );
    expect(first.right, lessThanOrEqualTo(second.left));
  });

  testWidgets('shows an explicit no-history message instead of a 0% rate', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, StudentStats.zeroFor('s1'));

    expect(find.text('Track record'), findsOneWidget);
    expect(
      find.text('No event history yet — this is their first event.'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(find.byKey(const ValueKey<String>('stat-events')), findsNothing);
  });

  testWidgets('reports the history as unavailable when the read fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: ApplicantDetailScreen(
        application: application(),
        getStudent: (String uid) async =>
            const Result<Student, Failure>.err(NotFoundFailure()),
        ratingsStream:
            Stream<List<RatingEntry>>.value(const <RatingEntry>[]),
        // e.g. offline, or security rules denying the counters.
        statsStream: Stream<StudentStats>.error(Exception('denied')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('stat-error')), findsOneWidget);
    expect(find.text('Loading history…'), findsNothing);
  });

  testWidgets('renders a 0% rate when approved events were never worked', (
    WidgetTester tester,
  ) async {
    await pumpDetail(
      tester,
      StudentStats(
        studentId: 's1',
        eventsParticipated: 4,
        attendanceCompleted: 0,
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('stat-rate')),
        matching: find.text('0%'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Completed attendance for 0 of 4 events on record (0%).'),
      findsOneWidget,
    );
  });
}
