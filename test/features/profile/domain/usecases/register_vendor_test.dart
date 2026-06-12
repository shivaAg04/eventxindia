import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/approval_status.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:eventxindia/features/profile/domain/repositories/profile_repository.dart';
import 'package:eventxindia/features/profile/domain/usecases/register_vendor.dart';
import 'package:eventxindia/features/profile/domain/validators/profile_validators.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileRepository implements ProfileRepository {
  final List<String> calls = <String>[];
  Vendor? createdVendor;

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) async {
    calls.add('createVendor');
    createdVendor = vendor;
    return Result<Vendor, Failure>.ok(vendor);
  }

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Student, Failure>> createStudent(Student student) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async {
    throw UnimplementedError();
  }
}

void main() {
  final DateTime now = DateTime(2025, 1, 1);

  VendorProfileInput validInput({
    String? aadhaarOrPan,
    String? website,
    List<String> socialLinks = const <String>[],
  }) {
    return VendorProfileInput(
      fullName: 'Ravi Kumar',
      agencyName: 'Kumar Events',
      phone: PhoneNumber.national('9876543210'),
      city: 'Mumbai',
      address: '12 MG Road',
      aadhaarOrPan: aadhaarOrPan,
      website: website,
      socialLinks: socialLinks,
    );
  }

  group('RegisterVendor', () {
    test('creates a vendor with Pending status on valid input', () async {
      final profile = _FakeProfileRepository();
      final useCase = RegisterVendor(profileRepository: profile);

      final result = await useCase.call(
        uid: 'v1',
        input: validInput(),
        now: now,
      );

      expect(result.isOk, isTrue);
      expect(profile.calls, <String>['createVendor']);
      expect(profile.createdVendor?.approvalStatus, ApprovalStatus.pending);
      expect(profile.createdVendor?.uid, 'v1');
    });

    test('stores provided optional fields', () async {
      final profile = _FakeProfileRepository();
      final useCase = RegisterVendor(profileRepository: profile);

      await useCase.call(
        uid: 'v1',
        input: validInput(
          aadhaarOrPan: 'ABCDE1234F',
          website: 'https://kumar.events',
          socialLinks: const <String>['https://x.com/kumar'],
        ),
        now: now,
      );

      expect(profile.createdVendor?.aadhaarOrPan, 'ABCDE1234F');
      expect(profile.createdVendor?.website, 'https://kumar.events');
      expect(profile.createdVendor?.socialLinks, <String>[
        'https://x.com/kumar',
      ]);
    });

    test('returns ValidationFailure and skips IO on invalid input', () async {
      final profile = _FakeProfileRepository();
      final useCase = RegisterVendor(profileRepository: profile);

      final input = VendorProfileInput(
        fullName: '',
        agencyName: '',
        phone: PhoneNumber.national('9876543210'),
        city: '',
        address: '',
      );

      final result = await useCase.call(uid: 'v1', input: input, now: now);

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull!.fieldErrors, isNotEmpty);
      expect(profile.calls, isEmpty);
    });
  });
}
