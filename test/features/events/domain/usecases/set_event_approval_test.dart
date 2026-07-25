import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/approval_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/events/domain/usecases/set_event_approval.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../applications/domain/fakes.dart';

Event pendingEvent() {
  final DateTime now = DateTime(2026, 1, 1, 9);
  return Event(
    eventId: 'e1',
    vendorId: 'v1',
    title: 'Catering Help',
    description: 'Serve guests.',
    date: DateTime(2026, 6, 1),
    startTime: DateTime(2026, 6, 1, 18),
    endTime: DateTime(2026, 6, 1, 23),
    location: EventLocation(
      label: 'Grand Hall',
      geo: GeoPoint(latitude: 1, longitude: 1),
    ),
    slots: 10,
    payPerHead: Money.fromMajorUnits(100),
    status: EventStatus.active,
    approvalStatus: ApprovalStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeEventRepository events;
  late SetEventApproval setApproval;

  setUp(() {
    events = FakeEventRepository()..seed(pendingEvent());
    setApproval = SetEventApproval(repository: events);
  });

  test('approving publishes the event', () async {
    final Result<Event, Failure> result =
        await setApproval(eventId: 'e1', status: ApprovalStatus.approved);
    expect(result.isOk, isTrue);
    expect(result.valueOrNull!.approvalStatus, ApprovalStatus.approved);
    expect(result.valueOrNull!.isPublished, isTrue);
  });

  test('rejecting keeps the event unpublished', () async {
    final Result<Event, Failure> result =
        await setApproval(eventId: 'e1', status: ApprovalStatus.rejected);
    expect(result.isOk, isTrue);
    expect(result.valueOrNull!.approvalStatus, ApprovalStatus.rejected);
    expect(result.valueOrNull!.isPublished, isFalse);
  });

  test('setting back to pending is a validation error and writes nothing',
      () async {
    final Result<Event, Failure> result =
        await setApproval(eventId: 'e1', status: ApprovalStatus.pending);
    expect(result.failureOrNull, isA<ValidationFailure>());
    // Unchanged in the repository.
    final Event stored = (await events.getById('e1')).valueOrNull!;
    expect(stored.approvalStatus, ApprovalStatus.pending);
  });

  test('a missing event surfaces the repository failure', () async {
    final Result<Event, Failure> result =
        await setApproval(eventId: 'missing', status: ApprovalStatus.approved);
    expect(result.failureOrNull, isA<NotFoundFailure>());
  });
}
