import 'package:eventxindia/features/attendance/domain/entities/attendance_record.dart';
import 'package:eventxindia/features/profile/domain/entities/student_stats.dart';
import 'package:eventxindia/features/profile/domain/student_stats_derivation.dart';
import 'package:glados/glados.dart';

void main() {
  final DateTime now = DateTime(2026, 8, 20);

  AttendanceRecord record({
    required String eventId,
    String studentId = 's1',
    bool checkedIn = true,
    bool checkedOut = true,
  }) {
    return AttendanceRecord(
      attendanceId: '${eventId}_$studentId',
      eventId: eventId,
      studentId: studentId,
      checkInTime: checkedIn ? now : null,
      checkOutTime: checkedOut ? now.add(const Duration(hours: 6)) : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('deriveStudentStats', () {
    test('counts every record as participation and completed ones separately',
        () {
      final StudentStats stats = deriveStudentStats(
        studentId: 's1',
        records: <AttendanceRecord>[
          record(eventId: 'e1'),
          record(eventId: 'e2', checkedOut: false), // still working
          record(eventId: 'e3'),
        ],
      );

      expect(stats.eventsParticipated, 3);
      expect(stats.attendanceCompleted, 2);
    });

    test('returns zeroed counters for a student with no records', () {
      expect(
        deriveStudentStats(studentId: 's1', records: <AttendanceRecord>[]),
        StudentStats.zeroFor('s1'),
      );
    });

    test('ignores records belonging to another student', () {
      final StudentStats stats = deriveStudentStats(
        studentId: 's1',
        records: <AttendanceRecord>[
          record(eventId: 'e1'),
          record(eventId: 'e2', studentId: 's2'),
          record(eventId: 'e3', studentId: 's2'),
        ],
      );

      expect(stats.eventsParticipated, 1);
      expect(stats.attendanceCompleted, 1);
      expect(stats.studentId, 's1');
    });

    test('does not count a check-out without a check-in as completed', () {
      final StudentStats stats = deriveStudentStats(
        studentId: 's1',
        records: <AttendanceRecord>[
          record(eventId: 'e1', checkedIn: false),
        ],
      );

      expect(stats.eventsParticipated, 1);
      expect(stats.attendanceCompleted, 0);
    });
  });

  group('deriveStudentStats properties', () {
    // Property: for any set of records, completed <= participated, both are
    // non-negative, and each equals the cardinality of its matching subset.
    Glados<List<bool>>(any.list(any.bool)).test(
      'completed never exceeds participated and both match their subsets',
      (List<bool> completedFlags) {
        final List<AttendanceRecord> records = <AttendanceRecord>[
          for (int i = 0; i < completedFlags.length; i++)
            record(eventId: 'e$i', checkedOut: completedFlags[i]),
        ];

        final StudentStats stats =
            deriveStudentStats(studentId: 's1', records: records);

        expect(stats.eventsParticipated, records.length);
        expect(
          stats.attendanceCompleted,
          completedFlags.where((bool done) => done).length,
        );
        expect(
          stats.attendanceCompleted,
          lessThanOrEqualTo(stats.eventsParticipated),
        );
      },
    );
  });
}
