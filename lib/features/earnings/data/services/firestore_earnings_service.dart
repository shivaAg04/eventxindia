import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/money.dart';
import '../../domain/entities/earnings.dart';
import '../../domain/repositories/earnings_repository.dart';
import '../../domain/services/earnings_service.dart';
import '../../domain/usecases/accrue.dart' as reducer;

/// Client-side binding for the trusted [EarningsService] (R11.1, R11.2, R14.4).
///
/// Earnings accrual is an **exactly-once backend capability** — today the
/// `accrueEarnings` Cloud Function triggered on completed attendance writes —
/// so the authoritative credit and the `earnings/{studentId}` write happen
/// server-side, never on the client. This implementation therefore provides
/// only the client/read surface: it reads the student's current [Earnings]
/// through the read-only [EarningsRepository] and applies the pure, idempotent
/// [accrue] reducer to compute the projected result, without writing.
///
/// Because [accrue] is keyed on `(studentId, eventId)` and the read repository
/// reflects the backend's authoritative document, repeated calls return the
/// already-credited projection unchanged (R11.2). No backend type crosses this
/// boundary — the implementation speaks pure domain [Earnings] and
/// `Result<T, Failure>` only.
@LazySingleton(as: EarningsService)
class FirestoreEarningsService implements EarningsService {
  /// Creates the service over the read-only [EarningsRepository].
  const FirestoreEarningsService(this._earningsRepository);

  final EarningsRepository _earningsRepository;

  @override
  Future<Result<Earnings, Failure>> accrue({
    required String studentId,
    required String eventId,
    required Money payPerHead,
  }) async {
    final Result<Earnings, Failure> current =
        await _earningsRepository.getByStudent(studentId);

    return current.map<Earnings>(
      (Earnings earnings) => reducer.accrue(
        earnings,
        reducer.CompletedAttendance(
          studentId: studentId,
          eventId: eventId,
          payPerHead: payPerHead,
        ),
      ),
    );
  }
}
