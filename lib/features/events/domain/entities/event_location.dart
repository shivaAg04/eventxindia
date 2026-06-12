import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/geo_point.dart';

/// The physical location of an event: a human-readable [label] paired with a
/// precise [geo] coordinate.
///
/// This is a small pure value object that keeps an event's place self-contained
/// (a display name plus the point used for attendance distance checks). The
/// [label] must be 1..200 characters after trimming; an empty or over-long
/// label throws an [ArgumentError]. The [geo] is a backend-neutral [GeoPoint],
/// so no backend type ever crosses the domain boundary.
class EventLocation extends Equatable {
  const EventLocation._({required this.label, required this.geo});

  /// The maximum number of characters allowed in a location [label].
  static const int maxLabelLength = 200;

  /// Creates an [EventLocation] from a [label] and [geo] coordinate.
  ///
  /// The [label] is trimmed and must be 1..[maxLabelLength] characters;
  /// otherwise an [ArgumentError] is thrown.
  factory EventLocation({required String label, required GeoPoint geo}) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > maxLabelLength) {
      throw ArgumentError.value(
        label,
        'label',
        'Location label must be 1..$maxLabelLength characters',
      );
    }
    return EventLocation._(label: trimmed, geo: geo);
  }

  /// A human-readable description of the location, e.g. a venue name or
  /// address. Always trimmed and 1..[maxLabelLength] characters.
  final String label;

  /// The geographic coordinate of the location, used for attendance distance
  /// validation.
  final GeoPoint geo;

  /// Returns a copy of this location with the given fields replaced.
  EventLocation copyWith({String? label, GeoPoint? geo}) {
    return EventLocation(
      label: label ?? this.label,
      geo: geo ?? this.geo,
    );
  }

  @override
  List<Object?> get props => <Object?>[label, geo];

  @override
  String toString() => 'EventLocation(label: $label, geo: $geo)';
}
