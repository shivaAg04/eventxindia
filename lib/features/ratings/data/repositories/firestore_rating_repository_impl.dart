import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/rating_entry.dart';
import '../../domain/repositories/rating_repository.dart';
import '../datasources/firestore_rating_data_source.dart';
import '../dtos/rating_dto.dart';

/// Firestore-backed implementation of [RatingRepository].
///
/// Stores ratings under the `ratings` collection keyed by the composite id
/// `"{eventId}_{studentId}"` via [FirestoreRatingDataSource], translating
/// between the pure domain [RatingEntry] and the [RatingDto] at the boundary.
/// No Firebase type crosses back into the domain.
///
/// The [submit] write is wrapped in the data-layer write-retry policy with
/// three attempts ([kDefaultMaxWriteAttempts]); on exhaustion it returns a
/// [PersistenceFailure] with no partial data committed.
@LazySingleton(as: RatingRepository)
class FirestoreRatingRepositoryImpl implements RatingRepository {
  const FirestoreRatingRepositoryImpl(this._dataSource);

  final FirestoreRatingDataSource _dataSource;

  @override
  Future<Result<RatingEntry, Failure>> submit(RatingEntry rating) async {
    return withRetry<RatingEntry>(
      kDefaultMaxWriteAttempts,
      () async {
        final RatingDto persisted =
            await _dataSource.create(RatingDto.fromEntity(rating));
        return persisted.toEntity();
      },
    );
  }

  @override
  Future<Result<RatingEntry?, Failure>> getById(String ratingId) async {
    try {
      final RatingDto? dto = await _dataSource.getById(ratingId);
      return Result<RatingEntry?, Failure>.ok(dto?.toEntity());
    } catch (_) {
      return const Result<RatingEntry?, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Stream<List<RatingEntry>> watchByStudent(String studentId) {
    return _dataSource.watchByStudent(studentId).map(_toEntities);
  }

  @override
  Stream<List<RatingEntry>> watchByEvent(String eventId) {
    return _dataSource.watchByEvent(eventId).map(_toEntities);
  }

  List<RatingEntry> _toEntities(List<RatingDto> dtos) =>
      dtos.map((RatingDto dto) => dto.toEntity()).toList(growable: false);
}
