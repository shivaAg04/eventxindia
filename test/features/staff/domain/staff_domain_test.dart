import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/staff/domain/entities/staff_member.dart';
import 'package:eventxindia/features/staff/domain/entities/staff_role.dart';
import 'package:eventxindia/features/staff/domain/repositories/staff_repository.dart';
import 'package:eventxindia/features/staff/domain/usecases/add_staff.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStaffRepository implements StaffRepository {
  final List<StaffMember> added = <StaffMember>[];
  final Set<String> existingIds = <String>{};

  @override
  Future<Result<StaffMember, Failure>> add(StaffMember staff) async {
    if (existingIds.contains(staff.staffId)) {
      return const Result<StaffMember, Failure>.err(
        StateTransitionFailure(message: 'This phone is already added as staff.'),
      );
    }
    existingIds.add(staff.staffId);
    added.add(staff);
    return Result<StaffMember, Failure>.ok(staff);
  }

  @override
  Future<Result<Unit, Failure>> remove(String staffId) async =>
      const Result<Unit, Failure>.ok(unit);

  @override
  Stream<List<StaffMember>> watchByVendor(String vendorId) =>
      Stream<List<StaffMember>>.value(added);

  @override
  Future<Result<StaffMember?, Failure>> findByPhone(String phoneE164) async =>
      Result<StaffMember?, Failure>.ok(null);

  @override
  Future<Result<StaffMember?, Failure>> provisionOnLogin({
    required String uid,
    required String phoneE164,
  }) async =>
      Result<StaffMember?, Failure>.ok(null);
}

void main() {
  final DateTime now = DateTime(2026, 7, 28, 9);

  group('StaffRole permissions', () {
    test('manager can do both', () {
      expect(StaffRole.manager.canManageApplicants, isTrue);
      expect(StaffRole.manager.canManageAttendance, isTrue);
    });

    test('applicantReviewer: applicants only', () {
      expect(StaffRole.applicantReviewer.canManageApplicants, isTrue);
      expect(StaffRole.applicantReviewer.canManageAttendance, isFalse);
    });

    test('attendanceStaff: attendance only', () {
      expect(StaffRole.attendanceStaff.canManageApplicants, isFalse);
      expect(StaffRole.attendanceStaff.canManageAttendance, isTrue);
    });

    test('wireName round-trips through parse', () {
      for (final StaffRole r in StaffRole.values) {
        expect(StaffRoleX.parse(r.wireName), r);
      }
      expect(StaffRoleX.tryParse('nope'), isNull);
    });
  });

  group('StaffMember', () {
    test('composite id strips non-digits from the phone', () {
      expect(
        StaffMember.buildId(vendorId: 'v1', phone: '+919876543210'),
        'v1_919876543210',
      );
    });
  });

  group('AddStaff', () {
    late _FakeStaffRepository repo;
    late AddStaff addStaff;

    setUp(() {
      repo = _FakeStaffRepository();
      addStaff = AddStaff(repository: repo, now: () => now);
    });

    test('normalises a 10-digit phone to +91 E.164 and persists', () async {
      final Result<StaffMember, Failure> result = await addStaff(
        vendorId: 'v1',
        input: const StaffInput(
          name: '  Asha  ',
          rawPhone: '9876543210',
          role: StaffRole.manager,
        ),
      );
      expect(result.isOk, isTrue);
      final StaffMember s = result.valueOrNull!;
      expect(s.name, 'Asha');
      expect(s.phone, '+919876543210');
      expect(s.vendorId, 'v1');
      expect(s.staffId, 'v1_919876543210');
      expect(s.active, isFalse);
      expect(s.uid, isNull);
    });

    test('rejects an empty name and a non-10-digit phone', () async {
      final Result<StaffMember, Failure> result = await addStaff(
        vendorId: 'v1',
        input: const StaffInput(
          name: '',
          rawPhone: '12345',
          role: StaffRole.manager,
        ),
      );
      final Failure? f = result.failureOrNull;
      expect(f, isA<ValidationFailure>());
      final Set<String> fields =
          (f! as ValidationFailure).fieldErrors.map((e) => e.field).toSet();
      expect(fields, containsAll(<String>['name', 'phone']));
      expect(repo.added, isEmpty);
    });

    test('surfaces a duplicate phone as a StateTransitionFailure', () async {
      const StaffInput input = StaffInput(
        name: 'Asha',
        rawPhone: '9876543210',
        role: StaffRole.attendanceStaff,
      );
      await addStaff(vendorId: 'v1', input: input);
      final Result<StaffMember, Failure> again =
          await addStaff(vendorId: 'v1', input: input);
      expect(again.failureOrNull, isA<StateTransitionFailure>());
      expect(repo.added.length, 1);
    });
  });
}
