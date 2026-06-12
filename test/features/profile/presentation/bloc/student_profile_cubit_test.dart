import 'package:bloc_test/bloc_test.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/phone_number.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:eventxindia/features/profile/domain/repositories/profile_repository.dart';
import 'package:eventxindia/features/profile/presentation/bloc/student_profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// A configurable fake so we exercise the cubit without mocking it.
class _FakeProfileRepository implements ProfileRepository {
  Result<Student, Failure> studentResult =
      const Result<Student, Failure>.err(NotFoundFailure());

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async =>
      studentResult;

  @override
  Future<Result<Student, Failure>> createStudent(Student student) async =>
      Result<Student, Failure>.ok(student);

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) async =>
      Result<Vendor, Failure>.ok(vendor);

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async =>
      const Result<Vendor, Failure>.err(NotFoundFailure());
}

void main() {
  final DateTime now = DateTime(2025, 1, 1);

  Student student() => Student(
        uid: 's1',
        fullName: 'Asha Rao',
        phone: PhoneNumber.national('9876543210'),
        gender: Gender.female,
        dateOfBirth: DateTime(2000, 5, 20),
        city: 'Pune',
        heightCm: 165,
        profilePhotoPath: 'students/s1/photo.jpg',
        createdAt: now,
        updatedAt: now,
      );

  group('StudentProfileCubit', () {
    blocTest<StudentProfileCubit, StudentProfileState>(
      'load emits [Loading, Loaded] with the profile on success (R4.6)',
      build: () {
        final repo = _FakeProfileRepository()
          ..studentResult = Result<Student, Failure>.ok(student());
        return StudentProfileCubit(repo);
      },
      act: (StudentProfileCubit cubit) => cubit.load('s1'),
      expect: () => <Matcher>[
        isA<StudentProfileLoading>(),
        isA<StudentProfileLoaded>().having(
          (StudentProfileLoaded s) => s.student.fullName,
          'fullName',
          'Asha Rao',
        ),
      ],
    );

    blocTest<StudentProfileCubit, StudentProfileState>(
      'load emits [Loading, Failure] when the read fails (R4.7)',
      build: () {
        final repo = _FakeProfileRepository()
          ..studentResult = const Result<Student, Failure>.err(
            PersistenceFailure(message: 'read failed'),
          );
        return StudentProfileCubit(repo);
      },
      act: (StudentProfileCubit cubit) => cubit.load('s1'),
      expect: () => <Matcher>[
        isA<StudentProfileLoading>(),
        isA<StudentProfileFailure>(),
      ],
    );
  });
}
