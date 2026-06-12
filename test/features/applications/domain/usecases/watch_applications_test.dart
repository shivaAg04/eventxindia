import 'package:eventxindia/core/value_objects/application_status.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/domain/usecases/watch_event_applications.dart';
import 'package:eventxindia/features/applications/domain/usecases/watch_student_applications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  final DateTime now = DateTime(2025, 1, 1, 9);

  Application application({
    required String eventId,
    required String studentId,
  }) {
    return Application(
      applicationId: '${eventId}_$studentId',
      eventId: eventId,
      studentId: studentId,
      status: ApplicationStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('WatchEventApplications', () {
    test('streams only the applications for the given event (R5.3)', () async {
      final repo = FakeApplicationRepository()
        ..seed(application(eventId: 'e1', studentId: 's1'))
        ..seed(application(eventId: 'e1', studentId: 's2'))
        ..seed(application(eventId: 'e2', studentId: 's3'));
      final useCase = WatchEventApplications(applicationRepository: repo);

      final List<Application> emitted = await useCase(eventId: 'e1').first;

      expect(emitted.map((Application a) => a.studentId),
          containsAll(<String>['s1', 's2']));
      expect(emitted.length, 2);
    });

    test('streams an empty list when the event has no applications', () async {
      final repo = FakeApplicationRepository();
      final useCase = WatchEventApplications(applicationRepository: repo);

      expect(await useCase(eventId: 'e1').first, isEmpty);
    });
  });

  group('WatchStudentApplications', () {
    test('streams only the applications for the given student (R4.2)',
        () async {
      final repo = FakeApplicationRepository()
        ..seed(application(eventId: 'e1', studentId: 's1'))
        ..seed(application(eventId: 'e2', studentId: 's1'))
        ..seed(application(eventId: 'e3', studentId: 's2'));
      final useCase = WatchStudentApplications(applicationRepository: repo);

      final List<Application> emitted = await useCase(studentId: 's1').first;

      expect(emitted.map((Application a) => a.eventId),
          containsAll(<String>['e1', 'e2']));
      expect(emitted.length, 2);
    });

    test('streams an empty list when the student has no applications',
        () async {
      final repo = FakeApplicationRepository();
      final useCase = WatchStudentApplications(applicationRepository: repo);

      expect(await useCase(studentId: 's1').first, isEmpty);
    });
  });
}
