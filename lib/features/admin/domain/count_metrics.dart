import '../../../core/value_objects/event_status.dart';
import '../../events/domain/entities/event.dart';
import '../../profile/domain/entities/student.dart';
import '../../profile/domain/entities/vendor.dart';
import 'entities/metrics.dart';

/// Computes the admin dashboard [Metrics] from the platform's collections
/// (R6.7).
///
/// This is a pure, side-effect-free function so it can be exercised
/// exhaustively by property tests and shared by the trusted aggregator's
/// logic. It maps directly onto the four admin counters:
///
/// - `totalStudents` = the number of registered [students].
/// - `totalVendors` = the number of registered [vendors].
/// - `activeEvents` = the number of [events] with status
///   [EventStatus.active].
/// - `completedEvents` = the number of [events] with status
///   [EventStatus.completed].
///
/// Each count is necessarily an integer of zero or greater, which [Metrics]
/// enforces at construction.
Metrics countMetrics({
  required List<Student> students,
  required List<Vendor> vendors,
  required List<Event> events,
}) {
  var activeEvents = 0;
  var completedEvents = 0;
  for (final Event event in events) {
    switch (event.status) {
      case EventStatus.active:
        activeEvents++;
      case EventStatus.completed:
        completedEvents++;
      case EventStatus.closed:
        break;
    }
  }

  return Metrics(
    totalStudents: students.length,
    totalVendors: vendors.length,
    activeEvents: activeEvents,
    completedEvents: completedEvents,
  );
}
