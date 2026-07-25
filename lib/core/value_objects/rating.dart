/// A vendor's star rating of a student for a single event.
///
/// Validity is enforced at construction: [stars] must be an integer in the
/// inclusive range `1 .. 5`. Ratings are whole stars only (no half-stars) and
/// carry no comment in V1. Mirrors the single-field, validating-factory shape
/// of [Money]/`GeoPoint` so an invalid rating can never be constructed.
class Rating {
  /// The number of stars, always within `1 .. 5`.
  final int stars;

  const Rating._(this.stars);

  /// The smallest allowed rating.
  static const int minStars = 1;

  /// The largest allowed rating.
  static const int maxStars = 5;

  /// Creates a [Rating] from a whole-star count.
  ///
  /// Throws an [ArgumentError] when [stars] is outside `1 .. 5`.
  factory Rating(int stars) {
    if (stars < minStars || stars > maxStars) {
      throw ArgumentError.value(
        stars,
        'stars',
        'Rating must be within $minStars .. $maxStars',
      );
    }
    return Rating._(stars);
  }

  /// Parses [stars], returning `null` instead of throwing for out-of-range or
  /// null input.
  static Rating? tryParse(int? stars) {
    if (stars == null || stars < minStars || stars > maxStars) {
      return null;
    }
    return Rating._(stars);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Rating && other.stars == stars);

  @override
  int get hashCode => stars.hashCode;

  @override
  String toString() => 'Rating($stars)';
}
