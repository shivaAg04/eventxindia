import 'dart:typed_data';

import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:eventxindia/features/profile/domain/repositories/profile_repository.dart';
import 'package:eventxindia/features/profile/domain/repositories/storage_repository.dart';
import 'package:eventxindia/features/profile/domain/usecases/register_student.dart';
import 'package:eventxindia/features/profile/domain/validators/profile_validators.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the order of calls so we can assert upload precedes create (R1.9).
class _FakeStorageRepository implements StorageRepository {
  _FakeStorageRepository({this.uploadResult});

  final List<String> calls = <String>[];
  PhotoUpload? lastPhoto;
  Result<String, Failure>? uploadResult;

  @override
  Future<Result<String, Failure>> uploadProfilePhoto({
    required String uid,
    required PhotoUpload photo,
  }) async {
    calls.add('upload');
    lastPhoto = photo;
    return uploadResult ?? Result<String, Failure>.ok('photos/$uid.jpg');
  }

  @override
  Future<Result<String, Failure>> getPhotoUrl(String reference) async {
    return Result<String, Failure>.ok('https://example.com/$reference');
  }
}

class _FakeProfileRepository implements ProfileRepository {
  final List<String> calls = <String>[];
  Student? createdStudent;

  @override
  Future<Result<Student, Failure>> createStudent(Student student) async {
    calls.add('createStudent');
    createdStudent = student;
    return Result<Student, Failure>.ok(student);
  }

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async {
    throw UnimplementedError();
  }
}

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

  StudentProfileInput validInput({PhotoUpload? photo}) {
    return StudentProfileInput(
      fullName: 'Asha Rao',
      phone: PhoneNumber.national('9876543210'),
      gender: Gender.female,
      dateOfBirth: DateTime(2000, 5, 20),
      city: 'Bengaluru',
      heightCm: 165,
      photo: photo ?? validPhoto(),
    );
  }

  group('RegisterStudent', () {
    test('uploads the photo then creates the student on valid input', () async {
      final storage = _FakeStorageRepository();
      final profile = _FakeProfileRepository();
      final useCase = RegisterStudent(
        profileRepository: profile,
        storageRepository: storage,
      );

      final result = await useCase.call(
        uid: 'u1',
        input: validInput(),
        now: now,
      );

      expect(result.isOk, isTrue);
      expect(storage.calls, <String>['upload']);
      expect(profile.calls, <String>['createStudent']);
      expect(profile.createdStudent?.profilePhotoPath, 'photos/u1.jpg');
      expect(profile.createdStudent?.uid, 'u1');
    });

    test('returns ValidationFailure and skips IO on invalid profile', () async {
      final storage = _FakeStorageRepository();
      final profile = _FakeProfileRepository();
      final useCase = RegisterStudent(
        profileRepository: profile,
        storageRepository: storage,
      );

      final input = StudentProfileInput(
        fullName: '',
        phone: PhoneNumber.national('9876543210'),
        gender: null,
        dateOfBirth: null,
        city: '',
        heightCm: null,
        photo: null,
      );

      final result = await useCase.call(uid: 'u1', input: input, now: now);

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull!.fieldErrors, isNotEmpty);
      expect(storage.calls, isEmpty);
      expect(profile.calls, isEmpty);
    });

    test('returns ValidationFailure for an oversized photo', () async {
      final storage = _FakeStorageRepository();
      final profile = _FakeProfileRepository();
      final useCase = RegisterStudent(
        profileRepository: profile,
        storageRepository: storage,
      );

      final result = await useCase.call(
        uid: 'u1',
        input: validInput(photo: validPhoto(sizeBytes: maxPhotoSizeBytes + 1)),
        now: now,
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(storage.calls, isEmpty);
      expect(profile.calls, isEmpty);
    });

    test('propagates a storage failure without creating the profile', () async {
      final storage = _FakeStorageRepository(
        uploadResult: const Result<String, Failure>.err(PersistenceFailure()),
      );
      final profile = _FakeProfileRepository();
      final useCase = RegisterStudent(
        profileRepository: profile,
        storageRepository: storage,
      );

      final result = await useCase.call(
        uid: 'u1',
        input: validInput(),
        now: now,
      );

      expect(result.failureOrNull, isA<PersistenceFailure>());
      expect(storage.calls, <String>['upload']);
      expect(profile.calls, isEmpty);
    });
  });
}
