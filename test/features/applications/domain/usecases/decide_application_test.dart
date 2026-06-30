import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/value_objects/application_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/domain/usecases/decide_application.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  final DateTime fixedNow = DateTime(2025, 1, 1, 9);
  final DateTime laterNow = DateTime(2025, 1, 2, 10);

  Event buildEvent({
    String vendorId = 'v1',
    int slots = 25,
    int approvedCount = 0,
  }) {
    return Event(
      eventId: 'e1',
      vendorId: vendorId,
      title: 'Catering Help',
      description: 'Serve guests.',
      date: DateTime(2025, 6, 1),
      startTime: DateTime(2025, 6, 1, 18),
      endTime: DateTime(2025, 6, 1, 23),
      location: EventLocation(
        label: 'Grand Hall',
        geo: GeoPoint(latitude: 12.34, longitude: 56.78),
      ),
      slots: slots,
      payPerHead: Money.fromMajorUnits(500),
      status: EventStatus.active,
      createdAt: fixedNow,
      updatedAt: fixedNow,
      approvedCount: approvedCount,
    );
  }

  Application buildApplication({
    ApplicationStatus status = ApplicationStatus.pending,
  }) {
    return Application(
      applicationId: 'e1_s1',
      eventId: 'e1',
      studentId: 's1',
      status: status,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    );
  }

  DecideApplication buildUseCase({
    required FakeApplicationRepository applications,
    required FakeEventRepository events,
  }) {
    return DecideApplication(
      applicationRepository: applications,
      eventRepository: events,
      now: () => laterNow,
    );
  }

  group('DecideApplication', () {
    test('approves a Pending application owned by the vendor (R9.3)', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository()..seed(buildApplication());
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'v1',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.approve,
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.status, ApplicationStatus.approved);
      expect(result.valueOrNull!.updatedAt, laterNow);
      expect(applications.decided.single.status, ApplicationStatus.approved);
    });

    test('approving increments the event approved count (seat filled)',
        () async {
      final events = FakeEventRepository()
        ..seed(buildEvent(slots: 2, approvedCount: 0));
      final applications = FakeApplicationRepository()..seed(buildApplication());
      final useCase = buildUseCase(applications: applications, events: events);

      await useCase(
        vendorId: 'v1',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.approve,
      );

      final Event after = (await events.getById('e1')).valueOrNull!;
      expect(after.approvedCount, 1);
      expect(after.seatsRemaining, 1);
    });

    test('cannot approve when the event is already full (capacity guard)',
        () async {
      final events = FakeEventRepository()
        ..seed(buildEvent(slots: 1, approvedCount: 1));
      final applications = FakeApplicationRepository()..seed(buildApplication());
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'v1',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.approve,
      );

      expect(result.failureOrNull, isA<StateTransitionFailure>());
      expect(applications.decided, isEmpty);
      // The full event's count is untouched.
      expect((await events.getById('e1')).valueOrNull!.approvedCount, 1);
    });

    test('rejecting a full event is still allowed (no capacity guard on reject)',
        () async {
      final events = FakeEventRepository()
        ..seed(buildEvent(slots: 1, approvedCount: 1));
      final applications = FakeApplicationRepository()..seed(buildApplication());
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'v1',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.reject,
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.status, ApplicationStatus.rejected);
    });

    test('rejects a Pending application owned by the vendor (R9.4)', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository()..seed(buildApplication());
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'v1',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.reject,
      );

      expect(result.valueOrNull!.status, ApplicationStatus.rejected);
    });

    test('denies when the vendor does not own the event (R5.9)', () async {
      final events = FakeEventRepository()..seed(buildEvent(vendorId: 'v1'));
      final applications = FakeApplicationRepository()..seed(buildApplication());
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'other',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.approve,
      );

      expect(result.failureOrNull, isA<AuthorizationFailure>());
      expect(applications.decided, isEmpty);
    });

    test('rejects when application is not Pending and leaves it unchanged '
        '(R5.8, R9.5)', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository()
        ..seed(buildApplication(status: ApplicationStatus.approved));
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'v1',
        applicationId: 'e1_s1',
        decision: ApplicationDecision.reject,
      );

      expect(result.failureOrNull, isA<StateTransitionFailure>());
      expect(applications.decided, isEmpty);
    });

    test('returns NotFound when the application is missing', () async {
      final events = FakeEventRepository()..seed(buildEvent());
      final applications = FakeApplicationRepository();
      final useCase = buildUseCase(applications: applications, events: events);

      final result = await useCase(
        vendorId: 'v1',
        applicationId: 'missing',
        decision: ApplicationDecision.approve,
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
