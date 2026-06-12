import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/student.dart';
import '../entities/vendor.dart';

/// Abstract gateway for persisting and reading [Student] and [Vendor]
/// profiles.
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firestore, later a
/// REST backend) lives in the data layer. No backend types ever cross this
/// boundary — every method speaks pure domain entities and
/// `Result<T, Failure>`.
///
/// A vendor's approval status is set to [ApprovalStatus.pending] at creation
/// and is never client-mutable through this interface; only an admin / trusted
/// backend may change it (R2.9, R6.1–R6.3).
abstract class ProfileRepository {
  /// Persists a newly created [student] profile (R1.6, R14.2).
  ///
  /// Returns the stored [Student] on success, or a [Failure] (e.g.
  /// [PersistenceFailure]) when the write fails.
  Future<Result<Student, Failure>> createStudent(Student student);

  /// Returns the student profile identified by [uid], or a [Failure] (e.g.
  /// [NotFoundFailure]) when no such profile exists.
  Future<Result<Student, Failure>> getStudent(String uid);

  /// Persists a newly created [vendor] profile with its approval status set to
  /// [ApprovalStatus.pending] (R2.9, R14.3).
  ///
  /// Returns the stored [Vendor] on success, or a [Failure] (e.g.
  /// [PersistenceFailure]) when the write fails.
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor);

  /// Returns the vendor profile identified by [uid], or a [Failure] (e.g.
  /// [NotFoundFailure]) when no such profile exists.
  Future<Result<Vendor, Failure>> getVendor(String uid);
}
