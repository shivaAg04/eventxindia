import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/approval_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/config/domain/repositories/platform_config_repository.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/usecases/create_event.dart';
import 'package:eventxindia/features/events/domain/validators/event_validators.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../applications/domain/fakes.dart';

class _FakeConfigRepository implements PlatformConfigRepository {
  @override
  Future<Result<int, Failure>> getCommissionPercent() async =>
      const Result<int, Failure>.ok(kDefaultCommissionPercent);

  @override
  Future<Result<Unit, Failure>> setCommissionPercent(int percent) async =>
      const Result<Unit, Failure>.ok(unit);

  @override
  Stream<int> watchCommissionPercent() =>
      Stream<int>.value(kDefaultCommissionPercent);
}

void main() {
  final DateTime now = DateTime(2026, 1, 1, 9);

  Vendor approvedVendor() => Vendor(
        uid: 'v1',
        fullName: 'Vendor One',
        agencyName: 'Agency One',
        phone: PhoneNumber.withCountryCode(
          countryCode: '+91',
          nationalNumber: '9876543210',
        ),
        city: 'Bengaluru',
        address: 'Some address',
        approvalStatus: ApprovalStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

  EventInput validInput() => EventInput(
        title: 'Catering Help',
        description: 'Serve guests at a wedding.',
        date: DateTime(2026, 6, 1),
        startTime: DateTime(2026, 6, 1, 18),
        endTime: DateTime(2026, 6, 1, 23),
        locationLabel: 'Grand Hall',
        geo: GeoPoint(latitude: 12.34, longitude: 56.78),
        slots: 25,
        payPerHead: Money.fromMajorUnits(100),
      );

  test('creates the event Active in lifecycle but PENDING admin approval',
      () async {
    final FakeEventRepository events = FakeEventRepository();
    final CreateEvent createEvent = CreateEvent(
      repository: events,
      configRepository: _FakeConfigRepository(),
    );

    final Result<Event, Failure> result = await createEvent(
      vendor: approvedVendor(),
      eventId: 'e1',
      input: validInput(),
      now: now,
    );

    expect(result.isOk, isTrue);
    final Event created = result.valueOrNull!;
    expect(created.status, EventStatus.active);
    // The publish gate: a brand-new event is NOT visible to students until an
    // admin approves it.
    expect(created.approvalStatus, ApprovalStatus.pending);
    expect(created.isPublished, isFalse);
  });
}
