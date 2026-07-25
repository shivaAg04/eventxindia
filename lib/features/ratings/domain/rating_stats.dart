import 'entities/rating_entry.dart';

/// Pure, backend-independent statistics over a set of [RatingEntry] records.

/// The simple arithmetic mean of the stars across [ratings], or `null` when
/// there are no ratings.
///
/// This is the student's overall average rating (R: a student's average is the
/// mean of all event ratings they have received).
double? averageStars(List<RatingEntry> ratings) {
  if (ratings.isEmpty) {
    return null;
  }
  final int total = ratings.fold<int>(
    0,
    (int sum, RatingEntry r) => sum + r.stars.stars,
  );
  return total / ratings.length;
}

/// Formats an average like `4.3`, or `'—'` when [average] is `null` (no
/// ratings yet). One decimal place.
String formatAverage(double? average) =>
    average == null ? '—' : average.toStringAsFixed(1);
