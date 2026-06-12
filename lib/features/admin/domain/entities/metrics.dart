import 'package:equatable/equatable.dart';

/// Aggregated platform counters shown on the Admin dashboard (R6.7).
///
/// A pure domain entity carrying the four admin counters. Each count is an
/// integer of zero or greater; validity is enforced at construction so a
/// [Metrics] value can never represent a negative count. The counters are
/// computed by the trusted `MetricsService` (Cloud Function `recomputeMetrics`
/// today) and read by the client; the domain layer never derives them from
/// backend types.
class Metrics extends Equatable {
  /// Creates a [Metrics] value, asserting every count is non-negative.
  ///
  /// Throws an [ArgumentError] if any of [totalStudents], [totalVendors],
  /// [activeEvents], or [completedEvents] is negative.
  Metrics({
    required this.totalStudents,
    required this.totalVendors,
    required this.activeEvents,
    required this.completedEvents,
  }) {
    _checkNonNegative('totalStudents', totalStudents);
    _checkNonNegative('totalVendors', totalVendors);
    _checkNonNegative('activeEvents', activeEvents);
    _checkNonNegative('completedEvents', completedEvents);
  }

  /// The number of registered students (>= 0) (R6.7).
  final int totalStudents;

  /// The number of registered vendors (>= 0) (R6.7).
  final int totalVendors;

  /// The number of events with status `Active` (>= 0) (R6.7).
  final int activeEvents;

  /// The number of events with status `Completed` (>= 0) (R6.7).
  final int completedEvents;

  /// A [Metrics] value with all counts at zero, used as the initial/empty
  /// state before any aggregation has run.
  static final Metrics zero = Metrics(
    totalStudents: 0,
    totalVendors: 0,
    activeEvents: 0,
    completedEvents: 0,
  );

  static void _checkNonNegative(String name, int value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must be zero or greater');
    }
  }

  @override
  List<Object?> get props => <Object?>[
        totalStudents,
        totalVendors,
        activeEvents,
        completedEvents,
      ];

  @override
  String toString() =>
      'Metrics(totalStudents: $totalStudents, totalVendors: $totalVendors, '
      'activeEvents: $activeEvents, completedEvents: $completedEvents)';
}
