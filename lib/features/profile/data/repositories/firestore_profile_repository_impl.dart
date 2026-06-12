import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/firestore_profile_data_source.dart';
import '../dtos/student_dto.dart';
import '../dtos/vendor_dto.dart';

/// Firestore-backed implementation of [ProfileRepository].
///
/// Persists student and vendor profiles to the `students/{uid}` and
/// `vendors/{uid}` collections (R14.2, R14.3). All writes go through the pure
/// [withRetry] policy (`maxAttempts = 3`) so a failed write is retried up to
/// three times and commits no partial data on total failure (R14.6). DTOs
/// (`StudentDto`/`VendorDto`) handle all Firebase ↔ domain mapping, so no
/// Firebase type crosses back to the use-case layer.
@LazySingleton(as: ProfileRepository)
class FirestoreProfileRepositoryImpl implements ProfileRepository {
  const FirestoreProfileRepositoryImpl(this._dataSource);

  final FirestoreProfileDataSource _dataSource;

  @override
  Future<Result<Student, Failure>> createStudent(Student student) async {
    final StudentDto dto = StudentDto.fromEntity(student);
    final Result<DocumentSnapshot<Map<String, dynamic>>, Failure> result =
        await withRetry<DocumentSnapshot<Map<String, dynamic>>>(
      kDefaultMaxWriteAttempts,
      () => _dataSource.setStudent(student.uid, dto.toFirestore()),
    );
    return result.map((doc) => StudentDto.fromFirestore(doc).toEntity());
  }

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _dataSource.getStudent(uid);
      if (!doc.exists) {
        return const Result<Student, Failure>.err(NotFoundFailure());
      }
      return Result<Student, Failure>.ok(
        StudentDto.fromFirestore(doc).toEntity(),
      );
    } catch (_) {
      return const Result<Student, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) async {
    final VendorDto dto = VendorDto.fromEntity(vendor);
    final Result<DocumentSnapshot<Map<String, dynamic>>, Failure> result =
        await withRetry<DocumentSnapshot<Map<String, dynamic>>>(
      kDefaultMaxWriteAttempts,
      () => _dataSource.setVendor(vendor.uid, dto.toFirestore()),
    );
    return result.map((doc) => VendorDto.fromFirestore(doc).toEntity());
  }

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _dataSource.getVendor(uid);
      if (!doc.exists) {
        return const Result<Vendor, Failure>.err(NotFoundFailure());
      }
      return Result<Vendor, Failure>.ok(
        VendorDto.fromFirestore(doc).toEntity(),
      );
    } catch (_) {
      return const Result<Vendor, Failure>.err(PersistenceFailure());
    }
  }
}
