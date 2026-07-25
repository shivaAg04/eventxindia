import 'package:eventxindia/core/value_objects/rating.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rating', () {
    test('accepts whole stars in 1..5', () {
      for (int s = Rating.minStars; s <= Rating.maxStars; s++) {
        expect(Rating(s).stars, s);
      }
    });

    test('rejects out-of-range stars', () {
      expect(() => Rating(0), throwsArgumentError);
      expect(() => Rating(6), throwsArgumentError);
      expect(() => Rating(-1), throwsArgumentError);
    });

    test('tryParse returns null for out-of-range or null', () {
      expect(Rating.tryParse(null), isNull);
      expect(Rating.tryParse(0), isNull);
      expect(Rating.tryParse(6), isNull);
      expect(Rating.tryParse(3)!.stars, 3);
    });

    test('value equality on stars', () {
      expect(Rating(4), Rating(4));
      expect(Rating(4) == Rating(5), isFalse);
      expect(Rating(4).hashCode, Rating(4).hashCode);
    });
  });
}
