import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../entities/withdrawal_request.dart';

/// Gateway for wallet withdrawal requests — the domain-owned swap line.
///
/// Use cases depend only on this interface; a backend-specific implementation
/// (today Firestore) lives in the data layer and no backend type ever crosses
/// this boundary. The credited balance itself is read through the existing
/// `EarningsRepository`; this gateway owns only the withdrawal side.
abstract class WalletRepository {
  /// Streams the withdrawal requests made by [studentId] (newest first).
  Stream<List<WithdrawalRequest>> watchByStudent(String studentId);

  /// Streams every withdrawal request across all students (admin view).
  Stream<List<WithdrawalRequest>> watchAll();

  /// Persists a new [request]. Returns the stored request or a [Failure].
  Future<Result<WithdrawalRequest, Failure>> create(WithdrawalRequest request);

  /// Records an admin's [decision] (approved/rejected) on the request
  /// identified by [id], stamping [decidedAt].
  Future<Result<Unit, Failure>> decide({
    required String id,
    required WithdrawalStatus decision,
    required DateTime decidedAt,
  });
}
