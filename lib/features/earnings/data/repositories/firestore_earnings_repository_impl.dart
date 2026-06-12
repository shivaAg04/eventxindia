import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/earnings.dart';
import '../../domain/repositories/earnings_repository.dart';
import '../datasources/firestore_earnings_data_source.dart';
import '../dtos/earnings_dto.dart';

/// Firestore implementation of the read-only [EarningsRepository].
///
/// Bridges the `earnings/{studentId}` collection to pure domain [Earnings]:
/// the [FirestoreEarningsDataSource] yields raw [DocumentSnapshot]s and
/// [EarningsDto] converts each into an entity. No Firebase type escapes this
/// layer (backend-independence rule).
///
/// This repository is **read-only**. The client never writes earnings —
/// accrual is the trusted backend's exactly-once responsibility (R11.1,
/// R11.2) — so there are deliberately no write methods here, and earnings are
/// persisted only by the backend `EarningsService` into the earnings
/// collection (R11.3, R11.4, R14.4).
///
/// A missing document maps to an empty projection (zero total, empty per-event
/// map), matching a student with no completed attendance records (R11.5).
@LazySingleton(as: EarningsRepository)
class FirestoreEarningsRepositoryImpl implements EarningsRepository {
  /// Creates the repository over the injected [FirestoreEarningsDataSource].
  const FirestoreEarningsRepositoryImpl(this._dataSource);

  final FirestoreEarningsDataSource _dataSource;

  @override
  Stream<Earnings> watchByStudent(String studentId) {
    return _dataSource.watchByStudent(studentId).map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              _toEntity(snapshot, studentId),
        );
  }

  @override
  Future<Result<Earnings, Failure>> getByStudent(String studentId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _dataSource.getByStudent(studentId);
      return Result<Earnings, Failure>.ok(_toEntity(snapshot, studentId));
    } catch (_) {
      return const Result<Earnings, Failure>.err(PersistenceFailure());
    }
  }

  /// Converts a Firestore snapshot into a domain [Earnings], falling back to an
  /// empty projection when the document does not exist (R11.5).
  Earnings _toEntity(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String studentId,
  ) {
    if (!snapshot.exists) {
      return Earnings.empty(studentId);
    }
    return EarningsDto.fromFirestore(snapshot).toEntity();
  }
}
