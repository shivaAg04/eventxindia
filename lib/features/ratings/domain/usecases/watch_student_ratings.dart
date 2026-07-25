import '../entities/rating_entry.dart';
import '../repositories/rating_repository.dart';

/// Streams every rating a student has received, backing their average rating
/// and per-event rating views (R rating).
class WatchStudentRatings {
  const WatchStudentRatings({required RatingRepository repository})
      : _repository = repository;

  final RatingRepository _repository;

  Stream<List<RatingEntry>> call(String studentId) =>
      _repository.watchByStudent(studentId);
}
