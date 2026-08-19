import 'dart:async';

import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/attendance/domain/entities/attendance_record.dart';
import 'package:eventxindia/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:eventxindia/features/profile/domain/entities/student_stats.dart';
import 'package:eventxindia/features/profile/domain/services/attendance_derived_student_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake of the repository, so the service is exercised without mocks
/// or any backend.
class _FakeAttendanceRepository implements AttendanceRepository {
  _FakeAttendanceRepository(this._controller);

  final StreamController<List<AttendanceRecord>> _controller;

  @override
  Stream<List<AttendanceRecord>> watchByStudent(String studentId) =>
      _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final DateTime now = DateTime(2026, 8, 20);

  AttendanceRecord record({
    required String eventId,
    bool checkedOut = true,
  }) {
    return AttendanceRecord(
      attendanceId: '${eventId}_s1',
      eventId: eventId,
      studentId: 's1',
      checkInTime: now,
      checkOutTime: checkedOut ? now.add(const Duration(hours: 5)) : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  late StreamController<List<AttendanceRecord>> controller;
  late AttendanceDerivedStudentStatsService service;

  setUp(() {
    controller = StreamController<List<AttendanceRecord>>();
    service = AttendanceDerivedStudentStatsService(
      attendanceRepository: _FakeAttendanceRepository(controller),
    );
  });

  tearDown(() => controller.close());

  group('watchStudentStats', () {
    test('maps the attendance stream to derived counters (R5.3)', () async {
      final Future<StudentStats> first = service.watchStudentStats('s1').first;
      controller.add(<AttendanceRecord>[
        record(eventId: 'e1'),
        record(eventId: 'e2', checkedOut: false),
        record(eventId: 'e3'),
      ]);

      final StudentStats stats = await first;

      expect(stats.eventsParticipated, 3);
      expect(stats.attendanceCompleted, 2);
      expect(stats.studentId, 's1');
    });

    test('emits zeroed counters for a student with no attendance', () async {
      final Future<StudentStats> first = service.watchStudentStats('s1').first;
      controller.add(const <AttendanceRecord>[]);

      expect(await first, StudentStats.zeroFor('s1'));
    });

    test('re-emits updated counters when the attendance stream changes',
        () async {
      final Future<List<StudentStats>> collected =
          service.watchStudentStats('s1').take(2).toList();

      controller.add(<AttendanceRecord>[record(eventId: 'e1')]);
      await Future<void>.delayed(Duration.zero);
      controller.add(<AttendanceRecord>[
        record(eventId: 'e1'),
        record(eventId: 'e2'),
      ]);

      final List<StudentStats> emissions = await collected;

      expect(emissions.first.attendanceCompleted, 1);
      expect(emissions.last.attendanceCompleted, 2);
    });
  });

  group('getStudentStats', () {
    test('returns an Ok with the derived counters', () async {
      final Future<Result<StudentStats, Failure>> result =
          service.getStudentStats('s1');
      controller.add(<AttendanceRecord>[record(eventId: 'e1')]);

      expect((await result).valueOrNull?.attendanceCompleted, 1);
    });

    test('returns a PersistenceFailure when the stream errors', () async {
      final Future<Result<StudentStats, Failure>> result =
          service.getStudentStats('s1');
      controller.addError(Exception('denied'));

      final Result<StudentStats, Failure> value = await result;

      expect(value.isErr, isTrue);
      expect(value.failureOrNull, isA<PersistenceFailure>());
    });
  });
}
