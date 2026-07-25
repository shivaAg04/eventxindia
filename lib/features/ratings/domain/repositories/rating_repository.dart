import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/rating_entry.dart';

/// Abstract gateway for persisting and observing student [RatingEntry] records.
///
/// The backend-swap line: no Firebase type crosses this boundary — every method
/// speaks pure domain [RatingEntry] values. Ratings are one-time (created once
/// per student per event, never updated), so there is only a create-style
/// [submit] plus read/watch surfaces.
abstract class RatingRepository {
  /// Persists a brand-new [rating]. Fails if a rating already exists for the
  /// same `{eventId}_{studentId}` (one-time rule).
  Future<Result<RatingEntry, Failure>> submit(RatingEntry rating);

  /// Reads the rating identified by [ratingId], or `Ok(null)` when none exists.
  Future<Result<RatingEntry?, Failure>> getById(String ratingId);

  /// Streams every rating a single student has received (R for the student's
  /// average + per-event view).
  Stream<List<RatingEntry>> watchByStudent(String studentId);

  /// Streams every rating recorded for a single event (vendor + admin views).
  Stream<List<RatingEntry>> watchByEvent(String eventId);
}
