import 'package:equatable/equatable.dart';

import '../../../events/domain/entities/event.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../domain/entities/metrics.dart';

/// States emitted by the `AdminBloc` and rendered by the admin screens (R6).
///
/// The bloc tracks two independent concerns — the monitoring lists and the
/// dashboard metrics — so a single state carries both projections. Distinct
/// state types let the screens react to exactly what changed:
/// * [AdminInitial] before any watch has started.
/// * [ListsLoaded] when the students/vendors/events lists are available
///   (R6.4–R6.6).
/// * [EmptyState] when every monitoring list is empty (R6.9).
/// * [MetricsLoaded] when the aggregated dashboard counters are available
///   (R6.7).
/// * [AdminActionFailure] when an approve/reject action or a watched stream
///   fails (R6.3).
sealed class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => <Object?>[];
}

/// The idle/initial state before any watch has started.
final class AdminInitial extends AdminState {
  const AdminInitial();
}

/// The monitoring lists have loaded (R6.4, R6.5, R6.6).
///
/// Carries the registered [students], the [vendors] each with its approval
/// status, and the [events] each with its status. [isEmpty] is true only when
/// all three lists are empty, in which case the screens show an empty-state
/// indication (R6.9).
final class ListsLoaded extends AdminState {
  const ListsLoaded({
    required this.students,
    required this.vendors,
    required this.events,
  });

  /// All registered students (R6.4).
  final List<Student> students;

  /// All registered vendors, each carrying its approval status (R6.5).
  final List<Vendor> vendors;

  /// All events, each carrying its lifecycle status (R6.6).
  final List<Event> events;

  /// Whether every monitoring list is empty (R6.9).
  bool get isEmpty => students.isEmpty && vendors.isEmpty && events.isEmpty;

  @override
  List<Object?> get props => <Object?>[students, vendors, events];
}

/// Every monitoring list is empty — no students, vendors, or events exist.
///
/// A dedicated state so the screens can render an empty-state indication
/// conveying that no records are available (R6.9).
final class EmptyState extends AdminState {
  const EmptyState();
}

/// The aggregated dashboard metrics have loaded (R6.7).
final class MetricsLoaded extends AdminState {
  const MetricsLoaded(this.metrics);

  /// The aggregated platform counters.
  final Metrics metrics;

  @override
  List<Object?> get props => <Object?>[metrics];
}

/// An admin action failed, or a watched stream errored (R6.3).
///
/// Carries a human-readable [message]; for an approve/reject rejection on a
/// non-`Pending` vendor this conveys that the vendor is not in a Pending state
/// (R6.3).
final class AdminActionFailure extends AdminState {
  const AdminActionFailure(this.message);

  /// A description of what went wrong, suitable for display.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
