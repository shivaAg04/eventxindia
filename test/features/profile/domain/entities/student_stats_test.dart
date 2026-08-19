import 'package:eventxindia/features/profile/domain/entities/student_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentStats', () {
    test('exposes the counters it was constructed with', () {
      final StudentStats stats = StudentStats(
        studentId: 's1',
        eventsParticipated: 12,
        attendanceCompleted: 11,
      );

      expect(stats.studentId, 's1');
      expect(stats.eventsParticipated, 12);
      expect(stats.attendanceCompleted, 11);
    });

    test('rejects a negative eventsParticipated at construction', () {
      expect(
        () => StudentStats(
          studentId: 's1',
          eventsParticipated: -1,
          attendanceCompleted: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative attendanceCompleted at construction', () {
      expect(
        () => StudentStats(
          studentId: 's1',
          eventsParticipated: 0,
          attendanceCompleted: -4,
        ),
        throwsArgumentError,
      );
    });

    test('zeroFor builds an empty track record for the given student', () {
      final StudentStats stats = StudentStats.zeroFor('s1');

      expect(stats.studentId, 's1');
      expect(stats.eventsParticipated, 0);
      expect(stats.attendanceCompleted, 0);
      expect(stats.isEmpty, isTrue);
    });

    test('isEmpty is false as soon as either counter is non-zero', () {
      expect(
        StudentStats(
          studentId: 's1',
          eventsParticipated: 1,
          attendanceCompleted: 0,
        ).isEmpty,
        isFalse,
      );
      expect(
        StudentStats(
          studentId: 's1',
          eventsParticipated: 0,
          attendanceCompleted: 1,
        ).isEmpty,
        isFalse,
      );
    });

    test('compares by value (Equatable)', () {
      expect(
        StudentStats(
          studentId: 's1',
          eventsParticipated: 2,
          attendanceCompleted: 1,
        ),
        StudentStats(
          studentId: 's1',
          eventsParticipated: 2,
          attendanceCompleted: 1,
        ),
      );
      expect(
        StudentStats(
          studentId: 's1',
          eventsParticipated: 2,
          attendanceCompleted: 1,
        ),
        isNot(
          StudentStats(
            studentId: 's2',
            eventsParticipated: 2,
            attendanceCompleted: 1,
          ),
        ),
      );
    });
  });
}
