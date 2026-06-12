import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:eventxindia/features/profile/domain/repositories/profile_repository.dart';
import 'package:eventxindia/features/profile/domain/repositories/storage_repository.dart';
import 'package:eventxindia/features/profile/domain/usecases/register_student.dart';
import 'package:eventxindia/features/profile/domain/usecases/register_vendor.dart';
import 'package:eventxindia/features/profile/domain/validators/profile_validators.dart';
import 'package:eventxindia/features/profile/presentation/bloc/registration_bloc.dart';
import 'package:eventxindia/features/profile/presentation/bloc/registration_event.dart';
import 'package:eventxindia/features/profile/presentation/bloc/registration_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A configurable fake repository so we exercise real use-case logic without
/// mocking the use cases themselves.
class _FakeProfileRepository implements ProfileRepository {
  Result<Student, Failure> studentResult =
      Result<Student, Failure>.err(const PersistenceFailure());
  Result<Vendor, Failure> vendorResult =
      Result<Vendor, Failure>.err(const PersistenceFailure());

  @override
  Future<Result<Student, Failure>> createStudent(Student student) async {
    return studentResult;
  }

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) async {
    return vendorResult;
  }

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async =>
      throw UnimplementedError();

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async =>
      throw UnimplementedError();
}

class _FakeStorageRepository implements StorageRepository {
  Result<String, Failure> uploadResult =
      Result<String, Failure>.ok('students/u1/photo.jpg');

  @override
  Future<Result<String, Failure>> uploadProfilePhoto({
    required String uid,
    required PhotoUpload photo,
  }) async {
    return uploadResult;
  }

  @override
  Future<Result<String, Failure>> getPhotoUrl(String reference) async =>
      throw UnimplementedError();
}

PhotoUpload _validPhoto() => PhotoUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentType: 'image/jpeg',
      fileName: 'p.jpg',
    );

void main() {
  final DateTime fixedNow = DateTime(2025, 1, 1);
  late _FakeProfileRepository profile;
  late _FakeStorageRepository storage;

  RegistrationBloc buildBloc() {
    return RegistrationBloc(
      registerStudent: RegisterStudent(
        profileRepository: profile,
        storageRepository: storage,
      ),
      registerVendor: RegisterVendor(profileRepository: profile),
      clock: () => fixedNow,
    );
  }

  setUp(() {
    profile = _FakeProfileRepository();
    storage = _FakeStorageRepository();
  });

  const validStudentForm = StudentFormData(
    fullName: 'Asha Rao',
    phone: '9876543210',
    gender: Gender.female,
    city: 'Pune',
    height: '165',
  );

  test('initial state is empty RegistrationEditing', () {
    expect(buildBloc().state, const RegistrationEditing());
  });

  blocTest<RegistrationBloc, RegistrationState>(
    'StudentFieldsChanged retains the entered values',
    build: buildBloc,
    act: (bloc) => bloc.add(const StudentFieldsChanged(validStudentForm)),
    expect: () => <RegistrationState>[
      const RegistrationEditing(studentForm: validStudentForm),
    ],
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'PhotoPicked updates only the photo and keeps other fields',
    build: buildBloc,
    seed: () => const RegistrationEditing(studentForm: validStudentForm),
    act: (bloc) => bloc.add(PhotoPicked(_validPhoto())),
    verify: (bloc) {
      final state = bloc.state as RegistrationEditing;
      expect(state.studentForm.photo, isNotNull);
      expect(state.studentForm.fullName, 'Asha Rao');
      expect(state.studentForm.city, 'Pune');
    },
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'StudentSubmitted surfaces field errors and retains values on invalid input',
    build: buildBloc,
    seed: () => const RegistrationEditing(
      studentForm: StudentFormData(phone: '9876543210'),
    ),
    act: (bloc) => bloc.add(const StudentSubmitted(uid: 'u1')),
    verify: (bloc) {
      final state = bloc.state as RegistrationEditing;
      expect(state.fieldErrors, isNotEmpty);
      // Entered value retained.
      expect(state.studentForm.phone, '9876543210');
      final fields = state.fieldErrors.map((e) => e.field).toSet();
      expect(fields, contains(ProfileFields.fullName));
      expect(fields, contains(ProfileFields.profilePhoto));
    },
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'StudentSubmitted reports phone parse error and retains values',
    build: buildBloc,
    seed: () => const RegistrationEditing(
      studentForm: StudentFormData(
        fullName: 'Asha Rao',
        phone: 'not-a-phone',
        gender: Gender.female,
        city: 'Pune',
        height: '165',
      ),
    ),
    act: (bloc) => bloc.add(const StudentSubmitted(uid: 'u1')),
    verify: (bloc) {
      final state = bloc.state as RegistrationEditing;
      final fields = state.fieldErrors.map((e) => e.field).toSet();
      expect(fields, contains('phone'));
      expect(state.studentForm.phone, 'not-a-phone');
    },
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'StudentSubmitted emits Submitting then Registered on success',
    build: () {
      profile.studentResult = Result<Student, Failure>.ok(
        Student(
          uid: 'u1',
          fullName: 'Asha Rao',
          phone: PhoneNumber.national('9876543210'),
          gender: Gender.female,
          dateOfBirth: DateTime(2000, 1, 1),
          city: 'Pune',
          heightCm: 165,
          profilePhotoPath: 'students/u1/photo.jpg',
          createdAt: fixedNow,
          updatedAt: fixedNow,
        ),
      );
      return buildBloc();
    },
    seed: () => RegistrationEditing(
      studentForm: StudentFormData(
        fullName: 'Asha Rao',
        phone: '9876543210',
        gender: Gender.female,
        dateOfBirth: DateTime(2000, 1, 1),
        city: 'Pune',
        height: '165',
        photo: _validPhoto(),
      ),
    ),
    act: (bloc) => bloc.add(const StudentSubmitted(uid: 'u1')),
    expect: () => <Matcher>[
      isA<RegistrationSubmitting>(),
      isA<Registered>(),
    ],
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'StudentSubmitted emits RegistrationFailure on storage failure',
    build: () {
      storage.uploadResult =
          Result<String, Failure>.err(const PersistenceFailure());
      return buildBloc();
    },
    seed: () => RegistrationEditing(
      studentForm: StudentFormData(
        fullName: 'Asha Rao',
        phone: '9876543210',
        gender: Gender.female,
        dateOfBirth: DateTime(2000, 1, 1),
        city: 'Pune',
        height: '165',
        photo: _validPhoto(),
      ),
    ),
    act: (bloc) => bloc.add(const StudentSubmitted(uid: 'u1')),
    expect: () => <Matcher>[
      isA<RegistrationSubmitting>(),
      isA<RegistrationFailure>(),
    ],
  );

  const validVendorForm = VendorFormData(
    fullName: 'Ravi Kumar',
    agencyName: 'Kumar Events',
    phone: '9876543210',
    city: 'Mumbai',
    address: '12 MG Road',
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'VendorSubmitted surfaces field errors and retains values on invalid input',
    build: buildBloc,
    seed: () => const RegistrationEditing(
      vendorForm: VendorFormData(phone: '9876543210'),
    ),
    act: (bloc) => bloc.add(const VendorSubmitted(uid: 'v1')),
    verify: (bloc) {
      final state = bloc.state as RegistrationEditing;
      expect(state.fieldErrors, isNotEmpty);
      expect(state.vendorForm.phone, '9876543210');
      final fields = state.fieldErrors.map((e) => e.field).toSet();
      expect(fields, contains(ProfileFields.agencyName));
      expect(fields, contains(ProfileFields.address));
    },
  );

  blocTest<RegistrationBloc, RegistrationState>(
    'VendorSubmitted emits Submitting then Registered on success',
    build: () {
      profile.vendorResult = Result<Vendor, Failure>.ok(
        Vendor.create(
          uid: 'v1',
          fullName: 'Ravi Kumar',
          agencyName: 'Kumar Events',
          phone: PhoneNumber.national('9876543210'),
          city: 'Mumbai',
          address: '12 MG Road',
          now: fixedNow,
        ),
      );
      return buildBloc();
    },
    seed: () => const RegistrationEditing(vendorForm: validVendorForm),
    act: (bloc) => bloc.add(const VendorSubmitted(uid: 'v1')),
    expect: () => <Matcher>[
      isA<RegistrationSubmitting>(),
      isA<Registered>(),
    ],
  );
}
