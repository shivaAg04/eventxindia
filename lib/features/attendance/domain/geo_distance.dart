import '../../../core/value_objects/geo_point.dart';

/// The great-circle distance in meters between two geographic points [a] and
/// [b], computed with the haversine formula over a spherical-earth
/// approximation (R10.3).
///
/// This is the attendance domain's canonical distance function: the check-in
/// flow compares its result against the 100-meter acceptance radius. It is a
/// pure function — no I/O, depends only on its arguments — and delegates to the
/// geometry co-located on [GeoPoint] so the formula has a single source of
/// truth.
///
/// The result is symmetric (`distanceMeters(a, b) == distanceMeters(b, a)`),
/// non-negative, and `0.0` when the two points are identical.
double distanceMeters(GeoPoint a, GeoPoint b) => a.distanceMetersTo(b);
