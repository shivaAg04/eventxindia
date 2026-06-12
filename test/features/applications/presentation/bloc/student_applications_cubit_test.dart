import 'package:bloc_test/bloc_test.dart';
import 'package:eventxindia/core/value_objects/application_status.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/domain/usecases/watch_student_applications.dart';
import 'package:eventxindia/features/applications/presentation/bloc/student_applications_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/fakes.dart';

void main() {
  final DateTime now = DateTime(2025, 1, 1, 9);

  Application application({
    required String eventId,
    required String studentId,
    ApplicationStatus status = ApplicationStatus.pending,
  }) {
    return Application(
      applicationId: '${eventId}_$studentId',
      eventId: eventId,
      studentId: studentId,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  StudentApplicationsCubit buildCubit(FakeApplicationRepository repo) =>
      StudentApplicationsCubit(
        WatchStudentApplications(applicationRepository: repo),
      );

  group('StudentApplicationsCubit', () {
    blocTest<StudentApplicationsCubit, StudentApplicationsState>(
      'watch with no filter emits every submitted application (R4.2)',
      build: () {
        final repo = FakeApplicationRepository()
          ..seed(application(eventId: 'e1', studentId: 's1'))
          ..seed(
            application(
              eventId: 'e2',
              studentId: 's1',
              status: ApplicationStatus.approved,
            ),
          )
          ..seed(application(eventId: 'e3', studentId: 's2'));
        return buildCubit(repo);
      },
      act: (StudentApplicationsCubit cubit) => cubit.watch(studentId: 's1'),
      expect: () => <Matcher>[
        isA<StudentApplicationsLoading>(),
        isA<StudentApplicationsLoaded>().having(
          (StudentApplicationsLoaded s) => s.applications.length,
          'count',
          2,
        ),
      ],
    );

    blocTest<StudentApplicationsCubit, StudentApplicationsState>(
      'watch with Approved filter emits only approved applications (R4.3)',
      build: () {
        final repo = FakeApplicationRepository()
          ..seed(application(eventId: 'e1', studentId: 's1'))
          ..seed(
            application(
              eventId: 'e2',
              studentId: 's1',
              status: ApplicationStatus.approved,
            ),
          );
        return buildCubit(repo);
      },
      act: (StudentApplicationsCubit cubit) => cubit.watch(
        studentId: 's1',
        statusFilter: ApplicationStatus.approved,
      ),
      expect: () => <Matcher>[
        isA<StudentApplicationsLoading>(),
        isA<StudentApplicationsLoaded>()
            .having(
              (StudentApplicationsLoaded s) => s.applications.length,
              'count',
              1,
            )
            .having(
              (StudentApplicationsLoaded s) => s.applications.single.eventId,
              'eventId',
              'e2',
            ),
      ],
    );

    blocTest<StudentApplicationsCubit, StudentApplicationsState>(
      'watch emits Empty when the student has no matching applications (R4.2)',
      build: () => buildCubit(FakeApplicationRepository()),
      act: (StudentApplicationsCubit cubit) => cubit.watch(studentId: 's1'),
      expect: () => <Matcher>[
        isA<StudentApplicationsLoading>(),
        isA<StudentApplicationsEmpty>(),
      ],
    );
  });
}
