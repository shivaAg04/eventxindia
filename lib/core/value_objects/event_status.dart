/// The lifecycle status of an event.
///
/// An event is [active] on creation and may transition to [closed] or
/// [completed]. Any value outside this set is rejected at the boundary via
/// [EventStatusX.parse].
enum EventStatus {
  active,
  closed,
  completed;

  /// The canonical wire/storage representation, e.g. `"Active"`.
  String get wireName {
    switch (this) {
      case EventStatus.active:
        return 'Active';
      case EventStatus.closed:
        return 'Closed';
      case EventStatus.completed:
        return 'Completed';
    }
  }
}

/// Parsing helpers that enforce validity for [EventStatus] at the boundary.
extension EventStatusX on EventStatus {
  /// Parses a wire/storage string into an [EventStatus].
  ///
  /// Accepts exactly `Active`, `Closed`, or `Completed`. Throws an
  /// [ArgumentError] for any unknown value.
  static EventStatus parse(String value) {
    for (final status in EventStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown EventStatus');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static EventStatus? tryParse(String value) {
    for (final status in EventStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }
    return null;
  }
}
