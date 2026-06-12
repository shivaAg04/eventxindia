part of 'event_management_bloc.dart';

/// Base type for all [EventManagementBloc] states rendered by the manage-events
/// and create-event screens.
///
/// States are compared by [Equatable] so the widget layer rebuilds only on a
/// genuine state change and `bloc_test` can assert exact emission sequences.
sealed class EventManagementState extends Equatable {
  const EventManagementState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The idle/initial state before any management action has started.
final class EventManagementInitial extends EventManagementState {
  const EventManagementInitial();
}

/// The create-event form is being edited.
///
/// Carries the latest [input] so the form retains the vendor's entered values,
/// and the set of [fieldErrors] to highlight after a rejected submission
/// (R7.2, R7.3). An empty [fieldErrors] is a clean editing state.
final class Editing extends EventManagementState {
  const Editing({this.input, this.fieldErrors = const <core.FieldError>[]});

  /// The current form input to retain, or `null` for a fresh form.
  final EventInput? input;

  /// The per-field validation errors to surface (empty when none).
  final List<core.FieldError> fieldErrors;

  @override
  List<Object?> get props => <Object?>[input, fieldErrors];
}

/// An event creation is in flight after [CreateRequested]; carries the
/// submitted [input] so the form can stay populated while disabled.
final class Creating extends EventManagementState {
  const Creating(this.input);

  /// The input being persisted.
  final EventInput input;

  @override
  List<Object?> get props => <Object?>[input];
}

/// The event was created successfully (R7.4).
final class Created extends EventManagementState {
  const Created(this.event);

  /// The newly created, active event.
  final Event event;

  @override
  List<Object?> get props => <Object?>[event];
}

/// The vendor's own events are available for the Manage Events view (R5.2).
final class VendorEventsLoaded extends EventManagementState {
  const VendorEventsLoaded(this.events);

  /// The events owned by the vendor, in stream order (empty when none).
  final List<Event> events;

  @override
  List<Object?> get props => <Object?>[events];
}

/// A management action failed — e.g. an unapproved vendor attempted to create
/// (R5.1), a non-owner attempted a status change (R5.9), or persistence failed.
final class EventManagementFailure extends EventManagementState {
  const EventManagementFailure(this.message);

  /// A human-readable description of why the action failed.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
