import 'package:equatable/equatable.dart';

import '../../../events/domain/entities/event.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../domain/entities/metrics.dart';

/// Events accepted by the `AdminBloc` (admin UI intents, R6).
///
/// Public events are dispatched by the admin screens; the private `_*` events
/// are dispatched internally by the bloc's own stream subscriptions to fold
/// asynchronous list/metrics updates back onto the single-threaded event loop.
sealed class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Requests approval of the vendor identified by [vendorId] (R6.1).
///
/// On success the watched vendor stream re-emits the updated approval status;
/// when the vendor is not in a `Pending` state the bloc surfaces an
/// `AdminActionFailure` and the existing status is retained (R6.3).
final class VendorApproveRequested extends AdminEvent {
  const VendorApproveRequested(this.vendorId);

  /// The id of the vendor to approve.
  final String vendorId;

  @override
  List<Object?> get props => <Object?>[vendorId];
}

/// Requests rejection of the vendor identified by [vendorId] (R6.2).
///
/// When the vendor is not in a `Pending` state the bloc surfaces an
/// `AdminActionFailure` and the existing status is retained (R6.3).
final class VendorRejectRequested extends AdminEvent {
  const VendorRejectRequested(this.vendorId);

  /// The id of the vendor to reject.
  final String vendorId;

  @override
  List<Object?> get props => <Object?>[vendorId];
}

/// Starts watching the admin monitoring lists: students, vendors, and events
/// (R6.4, R6.5, R6.6).
///
/// The bloc subscribes to all three streams and emits a combined `ListsLoaded`
/// once every list has produced its first value, or `EmptyState` when all
/// three lists are empty (R6.9).
final class ListsWatchStarted extends AdminEvent {
  const ListsWatchStarted();
}

/// Starts watching the aggregated dashboard [Metrics] (R6.7).
final class MetricsWatchStarted extends AdminEvent {
  const MetricsWatchStarted();
}

/// Internal: a new students snapshot arrived from the students stream.
final class StudentsUpdated extends AdminEvent {
  const StudentsUpdated(this.students);

  final List<Student> students;

  @override
  List<Object?> get props => <Object?>[students];
}

/// Internal: a new vendors snapshot arrived from the vendors stream.
final class VendorsUpdated extends AdminEvent {
  const VendorsUpdated(this.vendors);

  final List<Vendor> vendors;

  @override
  List<Object?> get props => <Object?>[vendors];
}

/// Internal: a new events snapshot arrived from the events stream.
final class EventsUpdated extends AdminEvent {
  const EventsUpdated(this.events);

  final List<Event> events;

  @override
  List<Object?> get props => <Object?>[events];
}

/// Internal: one of the list streams errored.
final class ListsErrored extends AdminEvent {
  const ListsErrored(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// Internal: a new aggregated [Metrics] value arrived from the metrics stream.
final class MetricsUpdated extends AdminEvent {
  const MetricsUpdated(this.metrics);

  final Metrics metrics;

  @override
  List<Object?> get props => <Object?>[metrics];
}

/// Internal: the metrics stream errored.
final class MetricsErrored extends AdminEvent {
  const MetricsErrored(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
