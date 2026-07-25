import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/rating.dart';
import '../entities/rating_entry.dart';
import '../repositories/rating_repository.dart';

/// Records a vendor's one-time star rating of a student for an event (R rating).
///
/// A rating is created only once per `{eventId}_{studentId}` and can never be
/// changed: if a rating already exists this returns a [StateTransitionFailure]
/// and writes nothing. Otherwise a fresh [RatingEntry] is stamped at [now] and
/// persisted. The caller is expected to have confirmed the student's check-out
/// is complete before rating; this use case enforces only the one-time rule.
///
/// Pure domain logic: depends on the repository abstraction and a [now] clock.
class RateStudent {
  const RateStudent({
    required RatingRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  final RatingRepository _repository;
  final DateTime Function() _now;

  /// Rates [studentId] on [eventId] with [stars]; [vendorId] is the rating
  /// author (the event owner). Returns the persisted [RatingEntry], or a
  /// [Failure] when a rating already exists or the write fails.
  Future<Result<RatingEntry, Failure>> call({
    required String eventId,
    required String studentId,
    required String vendorId,
    required Rating stars,
  }) async {
    final String ratingId =
        RatingEntry.buildId(eventId: eventId, studentId: studentId);

    final Result<RatingEntry?, Failure> existingResult =
        await _repository.getById(ratingId);
    if (existingResult.isErr) {
      return Result<RatingEntry, Failure>.err(
        existingResult.failureOrNull ?? const PersistenceFailure(),
      );
    }
    if (existingResult.valueOrNull != null) {
      return const Result<RatingEntry, Failure>.err(
        StateTransitionFailure(
          message: 'This student has already been rated for this event.',
        ),
      );
    }

    final RatingEntry rating = RatingEntry.create(
      eventId: eventId,
      studentId: studentId,
      vendorId: vendorId,
      stars: stars,
      now: _now(),
    );
    return _repository.submit(rating);
  }
}
