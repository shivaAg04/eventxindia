import 'dart:math' as math;

/// A pure, backend-neutral geographic coordinate value object.
///
/// This is intentionally **not** Firebase's `GeoPoint`: no backend type ever
/// crosses out of the data layer. Data-layer mappers convert Firebase's
/// `GeoPoint` to and from this value object.
///
/// Validity is enforced at construction: [latitude] must be within
/// `-90.0 .. 90.0` and [longitude] within `-180.0 .. 180.0`. Out-of-range or
/// non-finite values throw an [ArgumentError].
class GeoPoint {
  /// Latitude in decimal degrees, within `-90.0 .. 90.0`.
  final double latitude;

  /// Longitude in decimal degrees, within `-180.0 .. 180.0`.
  final double longitude;

  const GeoPoint._(this.latitude, this.longitude);

  /// Creates a geographic point from [latitude] and [longitude] in degrees.
  ///
  /// Throws an [ArgumentError] if either value is non-finite or out of range.
  factory GeoPoint({required double latitude, required double longitude}) {
    if (!latitude.isFinite || latitude < -90.0 || latitude > 90.0) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Latitude must be within -90.0 .. 90.0',
      );
    }
    if (!longitude.isFinite || longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Longitude must be within -180.0 .. 180.0',
      );
    }
    return GeoPoint._(latitude, longitude);
  }

  /// The great-circle distance in meters from this point to [other], computed
  /// with the haversine formula over a spherical-earth approximation.
  ///
  /// Provided as a convenience; the attendance domain owns the canonical
  /// `distanceMeters` use case, but co-locating the formula on the value object
  /// keeps the geometry pure and reusable.
  double distanceMetersTo(GeoPoint other) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);
    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
