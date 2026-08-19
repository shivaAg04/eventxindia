import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/profile/data/datasources/firestore_student_stats_data_source.dart';
import 'package:eventxindia/features/profile/data/services/firestore_student_stats_service.dart';
import 'package:eventxindia/features/profile/domain/entities/student_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements FirestoreStudentStatsDataSource {}

class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockDataSource dataSource;
  late FirestoreStudentStatsService service;

  setUp(() {
    dataSource = _MockDataSource();
    service = FirestoreStudentStatsService(dataSource);
  });

  DocumentSnapshot<Map<String, dynamic>> snapshot(Map<String, dynamic>? data) {
    final _MockDocumentSnapshot doc = _MockDocumentSnapshot();
    when(doc.data).thenReturn(data);
    return doc;
  }

  void stubWatch(Map<String, dynamic>? data) {
    when(() => dataSource.watchByStudent('s1')).thenAnswer(
      (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
        snapshot(data),
      ),
    );
  }

  group('watchStudentStats', () {
    test('maps the studentStats document to a domain StudentStats (R5.3)',
        () async {
      stubWatch(<String, dynamic>{
        'studentId': 's1',
        'eventsParticipated': 12,
        'attendanceCompleted': 11,
      });

      final StudentStats stats = await service.watchStudentStats('s1').first;

      expect(stats.studentId, 's1');
      expect(stats.eventsParticipated, 12);
      expect(stats.attendanceCompleted, 11);
      expect(stats.isEmpty, isFalse);
    });

    test('emits zeroed counters before any aggregation has run (missing doc)',
        () async {
      stubWatch(null);

      final StudentStats stats = await service.watchStudentStats('s1').first;

      expect(stats, StudentStats.zeroFor('s1'));
      expect(stats.isEmpty, isTrue);
    });

    test('treats missing, negative and non-numeric counters as zero', () async {
      stubWatch(<String, dynamic>{
        'eventsParticipated': -5,
        'attendanceCompleted': 'nonsense',
      });

      final StudentStats stats = await service.watchStudentStats('s1').first;

      expect(stats.eventsParticipated, 0);
      expect(stats.attendanceCompleted, 0);
    });

    test('carries the requested studentId even when the doc omits it',
        () async {
      stubWatch(<String, dynamic>{'eventsParticipated': 2});

      final StudentStats stats = await service.watchStudentStats('s1').first;

      expect(stats.studentId, 's1');
      expect(stats.eventsParticipated, 2);
    });
  });

  group('getStudentStats', () {
    test('returns an Ok with the mapped StudentStats on success', () async {
      when(() => dataSource.getByStudent('s1')).thenAnswer(
        (_) async => snapshot(<String, dynamic>{
          'eventsParticipated': 3,
          'attendanceCompleted': 2,
        }),
      );

      final Result<StudentStats, Failure> result =
          await service.getStudentStats('s1');

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull,
        StudentStats(
          studentId: 's1',
          eventsParticipated: 3,
          attendanceCompleted: 2,
        ),
      );
    });

    test('returns a PersistenceFailure when the read throws', () async {
      when(() => dataSource.getByStudent('s1')).thenThrow(Exception('boom'));

      final Result<StudentStats, Failure> result =
          await service.getStudentStats('s1');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<PersistenceFailure>());
    });
  });
}
