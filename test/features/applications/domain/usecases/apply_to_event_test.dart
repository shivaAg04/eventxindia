import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/value_objects/application_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/domain/usecases/apply_to_event.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  final DateTime fixedNow = DateTime(2025, 1, 1, 9);

  Event buildEvent({EventStatus status = EventStatus.active}) {
    return Event(
      eventId: 'e1',
      vendorId: 'v1',
      title: 'Catering Help',
      description: 'Serve guests.',
      date: DateTime(2025, 6, 1),
      startTime: DateTime(2025, 6, 1, 18),
      endTime: DateTime(2025, 6, 1, 23),
      location: EventLocation(
        label: 'Grand Hall',
        geo: GeoPoint(latitude: 12.34, longitude: 56.78),
      ),
      slots: 25,
      payPerHead: Money.fromMajorUnits(500),
      status: status,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    );
  }

  ApplyToEvent buildUseCase({
    required FakeEventRepository events,
    required FakeApplicationRepository applications,
    FakeProfileRepository? profiles,
  }) {
    return ApplyToEvent(
      eventRepository: events,
      applicationRepository: applications,
      profileRepository: profiles ?? FakeProfileRepository(),
      now: () => fixedNow,
    );
  }

  group('ApplyToEvent', () {
    test('creates a Pending application for an Active event (R9.1)', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository();
      final useCase = buildUseCase(events: events, applications: applications);

      final result = await useCase(studentId: 's1', eventId: 'e1');

      expect(result.isOk, isTrue);
      final Application created = result.valueOrNull!;
      expect(created.applicationId, 'e1_s1');
      expect(created.status, ApplicationStatus.pending);
      expect(created.createdAt, fixedNow);
      expect(applications.created.single.applicationId, 'e1_s1');
    });

    test('snapshots the applying student profile onto the application', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository();
      final profiles = FakeProfileRepository()
        ..seedStudent(
          Student(
            uid: 's1',
            fullName: 'Asha Rao',
            phone: PhoneNumber.withCountryCode(
              countryCode: '+91',
              nationalNumber: '9876543210',
            ),
            gender: Gender.female,
            dateOfBirth: DateTime(2000, 5, 20),
            city: 'Bengaluru',
            heightCm: 165,
            profilePhotoPath: '',
            createdAt: fixedNow,
            updatedAt: fixedNow,
          ),
        );
      final useCase = buildUseCase(
        events: events,
        applications: applications,
        profiles: profiles,
      );

      final result = await useCase(studentId: 's1', eventId: 'e1');

      final Application created = result.valueOrNull!;
      expect(created.applicantName, 'Asha Rao');
      expect(created.applicantPhone, '+919876543210');
      expect(created.applicantCity, 'Bengaluru');
    });

    test('snapshots the event display fields onto the application', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository();
      final useCase = buildUseCase(events: events, applications: applications);

      final result = await useCase(studentId: 's1', eventId: 'e1');

      final Application created = result.valueOrNull!;
      expect(created.eventTitle, 'Catering Help');
      expect(created.eventLocation, 'Grand Hall');
      expect(created.eventPayMinorUnits, 50000);
      expect(created.eventDate, DateTime(2025, 6, 1));
    });

    test('applies even when the student profile cannot be read (snapshot null)',
        () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository();
      final useCase = buildUseCase(events: events, applications: applications);

      final result = await useCase(studentId: 's1', eventId: 'e1');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.applicantName, isNull);
    });

    test('rejects and creates no record when event is not Active (R8.7)',
        () async {
      final events = FakeEventRepository()
        ..seed(buildEvent(status: EventStatus.closed));
      final applications = FakeApplicationRepository();
      final useCase = buildUseCase(events: events, applications: applications);

      final result = await useCase(studentId: 's1', eventId: 'e1');

      expect(result.failureOrNull, isA<StateTransitionFailure>());
      expect(applications.created, isEmpty);
    });

    test('surfaces a duplicate failure from the repository unchanged (R9.2)',
        () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository()
        ..createFailure = const StateTransitionFailure(
          message: 'Duplicate application.',
        );
      final useCase = buildUseCase(events: events, applications: applications);

      final result = await useCase(studentId: 's1', eventId: 'e1');

      expect(result.failureOrNull, isA<StateTransitionFailure>());
    });

    test('returns the repository failure when the event is missing', () async {
      final events = FakeEventRepository();
      final applications = FakeApplicationRepository();
      final useCase = buildUseCase(events: events, applications: applications);

      final result = await useCase(studentId: 's1', eventId: 'missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(applications.created, isEmpty);
    });
  });
}
