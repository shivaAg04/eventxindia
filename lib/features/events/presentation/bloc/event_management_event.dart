part of 'event_management_bloc.dart';

/// Base type for all [EventManagementBloc] events (UI intents in the vendor
/// event-management flow).
///
/// Events are pure value objects compared by [Equatable], so duplicate intents
/// are deduplicated by `bloc_test` and equality checks.
sealed class EventManagementEvent extends Equatable {
  const EventManagementEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The vendor submitted the create-event form (R5.1, R7.1–R7.4).
///
/// Carries the submitting [vendor] (whose approval status gates creation,
/// R5.1), the [eventId] to assign the new event, the raw [input] to validate
/// and persist, and the reference instant [now] used to validate the date and
/// stamp the event.
final class CreateRequested extends EventManagementEvent {
  const CreateRequested({
    required this.vendor,
    required this.eventId,
    required this.input,
    required this.now,
  });

  /// The vendor creating the event; must be [ApprovalStatus.approved] (R5.1).
  final Vendor vendor;

  /// The identifier to assign the new event (its persistence document id).
  final String eventId;

  /// The raw, pre-persistence event input to validate and create.
  final EventInput input;

  /// The reference instant for date validation and timestamps.
  final DateTime now;

  @override
  List<Object?> get props => <Object?>[vendor, eventId, input, now];
}

/// The vendor requested to transition the event identified by [eventId] to
/// [status] (R5.2, R7.5).
final class StatusChangeRequested extends EventManagementEvent {
  const StatusChangeRequested({
    required this.vendorId,
    required this.eventId,
    required this.status,
  });

  /// The id of the vendor requesting the change; must own the event (R5.9).
  final String vendorId;

  /// The id of the event whose status is changing.
  final String eventId;

  /// The requested target status.
  final EventStatus status;

  @override
  List<Object?> get props => <Object?>[vendorId, eventId, status];
}

/// Starts streaming the events owned by the vendor identified by [vendorId]
/// for the Manage Events view (R5.2).
final class VendorEventsWatchStarted extends EventManagementEvent {
  const VendorEventsWatchStarted(this.vendorId);

  /// The id of the vendor whose events should be streamed.
  final String vendorId;

  @override
  List<Object?> get props => <Object?>[vendorId];
}

/// Internal event carrying a fresh vendor-event set from the
/// [WatchVendorEvents] stream into the bloc's single-threaded event handler.
final class _VendorEventsUpdated extends EventManagementEvent {
  const _VendorEventsUpdated(this.events);

  /// The latest events owned by the vendor.
  final List<Event> events;

  @override
  List<Object?> get props => <Object?>[events];
}
