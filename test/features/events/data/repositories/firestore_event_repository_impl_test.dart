import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:eventxindia/core/value_objects/approval_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/events/data/datasources/firestore_event_data_source.dart';
import 'package:eventxindia/features/events/data/repositories/firestore_event_repository_impl.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Event buildEvent(
  String id, {
  EventStatus status = EventStatus.active,
  ApprovalStatus approval = ApprovalStatus.approved,
}) {
  final DateTime now = DateTime(2026, 1, 1, 9);
  return Event(
    eventId: id,
    vendorId: 'v1',
    title: 'Event $id',
    description: 'desc',
    date: DateTime(2030, 6, 1),
    startTime: DateTime(2030, 6, 1, 18),
    endTime: DateTime(2030, 6, 1, 23),
    location: EventLocation(
      label: 'Grand Hall',
      geo: GeoPoint(latitude: 1, longitude: 2),
    ),
    slots: 10,
    payPerHead: Money.fromMajorUnits(100),
    status: status,
    approvalStatus: approval,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreEventRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreEventRepositoryImpl(FirestoreEventDataSource(firestore));
  });

  test('watchActive emits only admin-approved (published) events', () async {
    await repo.create(buildEvent('approved'));
    await repo.create(
        buildEvent('pending', approval: ApprovalStatus.pending));
    await repo.create(
        buildEvent('rejected', approval: ApprovalStatus.rejected));

    final List<Event> active = await repo.watchActive().first;
    expect(active.map((Event e) => e.eventId), <String>['approved']);
  });

  test('create preserves the approvalStatus and getById reads it back',
      () async {
    await repo.create(buildEvent('e1', approval: ApprovalStatus.pending));
    final Event stored = (await repo.getById('e1')).valueOrNull!;
    expect(stored.approvalStatus, ApprovalStatus.pending);
    expect(stored.isPublished, isFalse);
  });

  test('setApprovalStatus publishes a pending event so watchActive shows it',
      () async {
    await repo.create(buildEvent('e1', approval: ApprovalStatus.pending));
    expect(await repo.watchActive().first, isEmpty);

    final result = await repo.setApprovalStatus('e1', ApprovalStatus.approved);
    expect(result.isOk, isTrue);

    final List<Event> active = await repo.watchActive().first;
    expect(active.single.eventId, 'e1');
    expect(active.single.approvalStatus, ApprovalStatus.approved);
  });

  test('a document without approvalStatus defaults to approved (published)',
      () async {
    // Simulate a legacy doc written before the moderation gate existed.
    await firestore.collection('events').doc('legacy').set(<String, dynamic>{
      'eventId': 'legacy',
      'vendorId': 'v1',
      'title': 'Legacy',
      'description': 'desc',
      'date': fs.Timestamp.fromDate(DateTime(2030, 6, 1)),
      'startTime': fs.Timestamp.fromDate(DateTime(2030, 6, 1, 18)),
      'endTime': fs.Timestamp.fromDate(DateTime(2030, 6, 1, 23)),
      'location': <String, dynamic>{
        'label': 'Hall',
        'geo': const fs.GeoPoint(1, 2),
      },
      'slots': 10,
      'payPerHead': 10000,
      'status': 'Active',
      'createdAt': fs.Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': fs.Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

    final List<Event> active = await repo.watchActive().first;
    expect(active.single.eventId, 'legacy');
    expect(active.single.approvalStatus, ApprovalStatus.approved);
  });
}
