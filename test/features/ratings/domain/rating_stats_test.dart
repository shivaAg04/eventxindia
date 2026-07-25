import 'package:eventxindia/core/value_objects/rating.dart';
import 'package:eventxindia/features/ratings/domain/entities/rating_entry.dart';
import 'package:eventxindia/features/ratings/domain/rating_stats.dart';
import 'package:flutter_test/flutter_test.dart';

RatingEntry _rating(String eventId, int stars) => RatingEntry(
      ratingId: '${eventId}_s1',
      eventId: eventId,
      studentId: 's1',
      vendorId: 'v1',
      stars: Rating(stars),
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('averageStars', () {
    test('is null with no ratings', () {
      expect(averageStars(const <RatingEntry>[]), isNull);
    });

    test('is the arithmetic mean of the stars', () {
      final List<RatingEntry> ratings = <RatingEntry>[
        _rating('e1', 5),
        _rating('e2', 4),
        _rating('e3', 3),
      ];
      expect(averageStars(ratings), closeTo(4.0, 1e-9));
    });

    test('handles a single rating', () {
      expect(averageStars(<RatingEntry>[_rating('e1', 2)]), 2.0);
    });
  });

  group('formatAverage', () {
    test('formats to one decimal, or dash when null', () {
      expect(formatAverage(null), '—');
      expect(formatAverage(4.0), '4.0');
      expect(formatAverage(4.333333), '4.3');
    });
  });
}
