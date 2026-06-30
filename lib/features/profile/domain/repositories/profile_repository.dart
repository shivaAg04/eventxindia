import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/student.dart';
import '../entities/vendor.dart';

/// Gateway for persisting and reading [Student] and [Vendor] profiles — the
/// backend swap line. Implemented by the data layer (today Firestore); no
/// backend type crosses it. Reads return [NotFoundFailure] when absent and
/// writes return [PersistenceFailure] on failure.
abstract class ProfileRepository {
  /// Persists a new [student] profile (R1.6, R14.2).
  Future<Result<Student, Failure>> createStudent(Student student);

  /// Returns the student profile identified by [uid].
  Future<Result<Student, Failure>> getStudent(String uid);

  /// Persists a new [vendor] profile with status [ApprovalStatus.pending]
  /// (R2.9, R14.3).
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor);

  /// Returns the vendor profile identified by [uid].
  Future<Result<Vendor, Failure>> getVendor(String uid);
}
