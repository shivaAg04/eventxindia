import 'dart:typed_data';

import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/repositories/storage_repository.dart';
import 'package:eventxindia/features/profile/domain/validators/profile_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2025, 1, 1);

  PhotoUpload validPhoto({
    int sizeBytes = 1024,
    String contentType = 'image/jpeg',
  }) {
    return PhotoUpload(
      bytes: Uint8List(sizeBytes),
      contentType: contentType,
      fileName: 'photo.jpg',
    );
  }

  StudentProfileInput validStudent({
    String fullName = 'Asha Rao',
    Gender? gender = Gender.female,
    DateTime? dateOfBirth,
    String city = 'Bengaluru',
    int? heightCm = 165,
    PhotoUpload? photo,
  }) {
    return StudentProfileInput(
      fullName: fullName,
      phone: PhoneNumber.national('9876543210'),
      gender: gender,
      dateOfBirth: dateOfBirth ?? DateTime(2000, 5, 20),
      city: city,
      heightCm: heightCm,
      photo: photo ?? validPhoto(),
    );
  }

  VendorProfileInput validVendor({
    String fullName = 'Ravi Kumar',
    String agencyName = 'Kumar Events',
    String city = 'Mumbai',
    String address = '12 MG Road',
  }) {
    return VendorProfileInput(
      fullName: fullName,
      agencyName: agencyName,
      phone: PhoneNumber.national('9876543210'),
      city: city,
      address: address,
    );
  }

  Set<String> fieldsOf(List errors) =>
      errors.map((e) => e.field as String).toSet();

  group('validateStudentProfile', () {
    test('returns no errors for a fully valid profile', () {
      expect(validateStudentProfile(validStudent(), now: now), isEmpty);
    });

    test('flags an empty full name', () {
      final errors = validateStudentProfile(
        validStudent(fullName: '  '),
        now: now,
      );
      expect(fieldsOf(errors), contains(ProfileFields.fullName));
    });

    test('flags a full name longer than 100 characters', () {
      final errors = validateStudentProfile(
        validStudent(fullName: 'a' * 101),
        now: now,
      );
      expect(fieldsOf(errors), contains(ProfileFields.fullName));
    });

    test('flags a missing gender', () {
      final errors = validateStudentProfile(
        validStudent(gender: null),
        now: now,
      );
      expect(fieldsOf(errors), contains(ProfileFields.gender));
    });

    test('flags a date of birth that is not in the past', () {
      final errors = validateStudentProfile(
        validStudent(dateOfBirth: now),
        now: now,
      );
      expect(fieldsOf(errors), contains(ProfileFields.dateOfBirth));
    });

    test('flags height below 50 and above 250', () {
      expect(
        fieldsOf(validateStudentProfile(validStudent(heightCm: 49), now: now)),
        contains(ProfileFields.heightCm),
      );
      expect(
        fieldsOf(validateStudentProfile(validStudent(heightCm: 251), now: now)),
        contains(ProfileFields.heightCm),
      );
    });

    test('accepts boundary heights 50 and 250', () {
      expect(
        validateStudentProfile(validStudent(heightCm: 50), now: now),
        isEmpty,
      );
      expect(
        validateStudentProfile(validStudent(heightCm: 250), now: now),
        isEmpty,
      );
    });

    test('allows a missing photo (the photo is optional)', () {
      final input = StudentProfileInput(
        fullName: 'Asha Rao',
        phone: PhoneNumber.national('9876543210'),
        gender: Gender.female,
        dateOfBirth: DateTime(2000, 5, 20),
        city: 'Bengaluru',
        heightCm: 165,
        photo: null,
      );
      expect(validateStudentProfile(input, now: now), isEmpty);
    });

    test('reports every offending field at once', () {
      final input = StudentProfileInput(
        fullName: '',
        phone: PhoneNumber.national('9876543210'),
        gender: null,
        dateOfBirth: null,
        city: '',
        heightCm: null,
        photo: null,
      );
      expect(
        fieldsOf(validateStudentProfile(input, now: now)),
        <String>{
          ProfileFields.fullName,
          ProfileFields.gender,
          ProfileFields.dateOfBirth,
          ProfileFields.city,
          ProfileFields.heightCm,
        },
      );
    });
  });

  group('validatePhoto', () {
    test('accepts a JPEG within the size limit', () {
      expect(validatePhoto(validPhoto(contentType: 'image/jpeg')), isEmpty);
    });

    test('accepts a PNG within the size limit', () {
      expect(validatePhoto(validPhoto(contentType: 'image/png')), isEmpty);
    });

    test('accepts a photo exactly at 5 MB', () {
      expect(validatePhoto(validPhoto(sizeBytes: maxPhotoSizeBytes)), isEmpty);
    });

    test('flags a photo over 5 MB', () {
      final errors = validatePhoto(
        validPhoto(sizeBytes: maxPhotoSizeBytes + 1),
      );
      expect(fieldsOf(errors), contains(ProfileFields.profilePhoto));
    });

    test('flags an unsupported content type', () {
      final errors = validatePhoto(validPhoto(contentType: 'image/gif'));
      expect(fieldsOf(errors), contains(ProfileFields.profilePhoto));
    });
  });

  group('validateVendorProfile', () {
    test('returns no errors for a fully valid profile', () {
      expect(validateVendorProfile(validVendor()), isEmpty);
    });

    test('flags an empty full name', () {
      expect(
        fieldsOf(validateVendorProfile(validVendor(fullName: ''))),
        contains(ProfileFields.fullName),
      );
    });

    test('flags an agency name longer than 150 characters', () {
      expect(
        fieldsOf(validateVendorProfile(validVendor(agencyName: 'a' * 151))),
        contains(ProfileFields.agencyName),
      );
    });

    test('flags an empty city', () {
      expect(
        fieldsOf(validateVendorProfile(validVendor(city: '   '))),
        contains(ProfileFields.city),
      );
    });

    test('flags an address longer than 250 characters', () {
      expect(
        fieldsOf(validateVendorProfile(validVendor(address: 'a' * 251))),
        contains(ProfileFields.address),
      );
    });

    test('reports every offending field at once', () {
      final input = VendorProfileInput(
        fullName: '',
        agencyName: '',
        phone: PhoneNumber.national('9876543210'),
        city: '',
        address: '',
      );
      expect(
        fieldsOf(validateVendorProfile(input)),
        <String>{
          ProfileFields.fullName,
          ProfileFields.agencyName,
          ProfileFields.city,
          ProfileFields.address,
        },
      );
    });

    test('does not require optional fields', () {
      final input = VendorProfileInput(
        fullName: 'Ravi Kumar',
        agencyName: 'Kumar Events',
        phone: PhoneNumber.national('9876543210'),
        city: 'Mumbai',
        address: '12 MG Road',
        aadhaarOrPan: null,
        website: null,
        socialLinks: const <String>[],
      );
      expect(validateVendorProfile(input), isEmpty);
    });
  });
}
