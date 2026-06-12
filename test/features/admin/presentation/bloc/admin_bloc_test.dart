import 'package:bloc_test/bloc_test.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/approval_status.dart';
import 'package:eventxindia/core/value_objects/event_status.dart';
import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/admin/domain/entities/metrics.dart';
import 'package:eventxindia/features/admin/domain/usecases/approve_vendor.dart';
import 'package:eventxindia/features/admin/domain/usecases/get_metrics.dart';
import 'package:eventxindia/features/admin/domain/usecases/list_events.dart';
import 'package:eventxindia/features/admin/domain/usecases/list_students.dart';
import 'package:eventxindia/features/admin/domain/usecases/list_vendors.dart';
import 'package:eventxindia/features/admin/domain/usecases/reject_vendor.dart';
import 'package:eventxindia/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:eventxindia/features/admin/presentation/bloc/admin_event.dart';
import 'package:eventxindia/features/admin/presentation/bloc/admin_state.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApproveVendor extends Mock implements ApproveVendor {}

class _MockRejectVendor extends Mock implements RejectVendor {}

class _MockListStudents extends Mock implements ListStudents {}

class _MockListVendors extends Mock implements ListVendors {}

class _MockListEvents extends Mock implements ListEvents {}

class _MockGetMetrics extends Mock implements GetMetrics {}

final _now = DateTime(2025, 1, 1, 9);

Student _student(String uid) => Student(
      uid: uid,
      fullName: 'Student $uid',
      phone: PhoneNumber.parse('9876543210'),
      gender: Gender.male,
      dateOfBirth: DateTime(2000, 1, 1),
      city: 'Pune',
      heightCm: 170,
      profilePhotoPath: 'photos/$uid.jpg',
      createdAt: _now,
      updatedAt: _now,
    );

Vendor _vendor(String uid, ApprovalStatus status) => Vendor(
      uid: uid,
      fullName: 'Vendor $uid',
      agencyName: 'Agency $uid',
      phone: PhoneNumber.parse('9876543211'),
      city: 'Mumbai',
      address: '123 Street',
      approvalStatus: status,
      createdAt: _now,
      updatedAt: _now,
    );

Event _event(String id, EventStatus status) => Event(
      eventId: id,
      vendorId: 'v1',
      title: 'Event $id',
      description: 'desc',
      date: DateTime(2025, 6, 1),
      startTime: DateTime(2025, 6, 1, 18),
      endTime: DateTime(2025, 6, 1, 23),
      location: EventLocation(
        label: 'Hall',
        geo: GeoPoint(latitude: 12.34, longitude: 56.78),
      ),
      slots: 10,
      payPerHead: Money.fromMajorUnits(500),
      status: status,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  late _MockApproveVendor approveVendor;
  late _MockRejectVendor rejectVendor;
  late _MockListStudents listStudents;
  late _MockListVendors listVendors;
  late _MockListEvents listEvents;
  late _MockGetMetrics getMetrics;

  setUp(() {
    approveVendor = _MockApproveVendor();
    rejectVendor = _MockRejectVendor();
    listStudents = _MockListStudents();
    listVendors = _MockListVendors();
    listEvents = _MockListEvents();
    getMetrics = _MockGetMetrics();
  });

  AdminBloc build() => AdminBloc(
        approveVendor,
        rejectVendor,
        listStudents,
        listVendors,
        listEvents,
        getMetrics,
      );

  void stubEmptyLists() {
    when(listStudents.call)
        .thenAnswer((_) => Stream<List<Student>>.value(const <Student>[]));
    when(listVendors.call)
        .thenAnswer((_) => Stream<List<Vendor>>.value(const <Vendor>[]));
    when(listEvents.call)
        .thenAnswer((_) => Stream<List<Event>>.value(const <Event>[]));
  }

  group('AdminBloc', () {
    test('initial state is AdminInitial', () {
      expect(build().state, const AdminInitial());
    });

    blocTest<AdminBloc, AdminState>(
      'emits ListsLoaded once all three lists arrive (R6.4, R6.5, R6.6)',
      setUp: () {
        when(listStudents.call).thenAnswer(
          (_) => Stream<List<Student>>.value(<Student>[_student('s1')]),
        );
        when(listVendors.call).thenAnswer(
          (_) => Stream<List<Vendor>>.value(
            <Vendor>[_vendor('v1', ApprovalStatus.pending)],
          ),
        );
        when(listEvents.call).thenAnswer(
          (_) => Stream<List<Event>>.value(
            <Event>[_event('e1', EventStatus.active)],
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const ListsWatchStarted()),
      expect: () => <Matcher>[
        isA<ListsLoaded>()
            .having((s) => s.students.length, 'students', 1)
            .having((s) => s.vendors.length, 'vendors', 1)
            .having((s) => s.events.length, 'events', 1),
      ],
    );

    blocTest<AdminBloc, AdminState>(
      'emits EmptyState when every list is empty (R6.9)',
      setUp: stubEmptyLists,
      build: build,
      act: (bloc) => bloc.add(const ListsWatchStarted()),
      expect: () => <AdminState>[const EmptyState()],
    );

    blocTest<AdminBloc, AdminState>(
      'emits MetricsLoaded for the aggregated counters (R6.7)',
      setUp: () {
        when(getMetrics.call).thenAnswer(
          (_) => Stream<Metrics>.value(
            Metrics(
              totalStudents: 3,
              totalVendors: 2,
              activeEvents: 1,
              completedEvents: 4,
            ),
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const MetricsWatchStarted()),
      expect: () => <Matcher>[
        isA<MetricsLoaded>().having(
          (s) => s.metrics.totalStudents,
          'totalStudents',
          3,
        ),
      ],
    );

    blocTest<AdminBloc, AdminState>(
      'emits AdminActionFailure when approving a non-Pending vendor (R6.3)',
      setUp: () {
        when(() => approveVendor('v1')).thenAnswer(
          (_) async => const Err<Vendor, Failure>(StateTransitionFailure()),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const VendorApproveRequested('v1')),
      expect: () => <Matcher>[isA<AdminActionFailure>()],
    );

    blocTest<AdminBloc, AdminState>(
      'emits AdminActionFailure when rejecting a non-Pending vendor (R6.3)',
      setUp: () {
        when(() => rejectVendor('v1')).thenAnswer(
          (_) async => const Err<Vendor, Failure>(StateTransitionFailure()),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const VendorRejectRequested('v1')),
      expect: () => <Matcher>[isA<AdminActionFailure>()],
    );

    blocTest<AdminBloc, AdminState>(
      'approve success emits no state; status reflected via list stream (R6.1)',
      setUp: () {
        when(() => approveVendor('v1')).thenAnswer(
          (_) async => Ok<Vendor, Failure>(
            _vendor('v1', ApprovalStatus.approved),
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const VendorApproveRequested('v1')),
      expect: () => const <AdminState>[],
    );
  });
}
