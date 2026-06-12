import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart' as core;
import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../domain/entities/event.dart';
import '../../domain/usecases/change_event_status.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/watch_vendor_events.dart';
import '../../domain/validators/event_validators.dart';

part 'event_management_event.dart';
part 'event_management_state.dart';

/// Presentation-layer state machine for vendor event management: creating
/// events, changing their status, and watching the vendor's own events
/// (R5.1, R5.2, R7.1–R7.5).
///
/// [EventManagementBloc] translates UI intent ([EventManagementEvent]s) into
/// calls on the management use cases and emits [EventManagementState]s the
/// manage-events and create-event screens render. Per the architecture's
/// dependency rule it depends *only* on use cases ([CreateEvent],
/// [ChangeEventStatus], [WatchVendorEvents]) injected via the constructor —
/// never on a repository or any Firebase type.
///
/// Event → state mapping:
/// * [CreateRequested] → `[Creating]`, then `[Created]` on success. On a
///   validation failure it emits [Editing] carrying the submitted [EventInput]
///   (so the form retains the entered values) and the exact set of field errors
///   (R7.2, R7.3). A non-approved vendor is gated before validation and surfaces
///   an [EventManagementFailure] (R5.1).
/// * [StatusChangeRequested] → emits [EventManagementFailure] on a rejected
///   transition (non-owner or persistence error); the watch stream reflects a
///   successful change (R5.2, R7.5).
/// * [VendorEventsWatchStarted] → streams the vendor's events and emits
///   [VendorEventsLoaded] (R5.2).
@injectable
class EventManagementBloc
    extends Bloc<EventManagementEvent, EventManagementState> {
  EventManagementBloc(
    this._createEvent,
    this._changeEventStatus,
    this._watchVendorEvents,
  ) : super(const EventManagementInitial()) {
    on<CreateRequested>(_onCreateRequested);
    on<StatusChangeRequested>(_onStatusChangeRequested);
    on<VendorEventsWatchStarted>(_onVendorEventsWatchStarted);
    on<_VendorEventsUpdated>(_onVendorEventsUpdated);
  }

  final CreateEvent _createEvent;
  final ChangeEventStatus _changeEventStatus;
  final WatchVendorEvents _watchVendorEvents;

  StreamSubscription<List<Event>>? _subscription;

  Future<void> _onCreateRequested(
    CreateRequested event,
    Emitter<EventManagementState> emit,
  ) async {
    // Gate creation on the vendor's approval status before doing any work, so
    // an unapproved vendor never reaches validation or persistence (R5.1).
    if (event.vendor.approvalStatus != ApprovalStatus.approved) {
      emit(
        const EventManagementFailure(
          'Only approved vendors can create events.',
        ),
      );
      return;
    }

    emit(Creating(event.input));

    final result = await _createEvent(
      vendor: event.vendor,
      eventId: event.eventId,
      input: event.input,
      now: event.now,
    );

    result.fold(
      (Event created) => emit(Created(created)),
      (core.Failure failure) {
        // Surface field errors and retain the entered values so the form can
        // re-render with the user's input intact (R7.2, R7.3).
        if (failure is core.ValidationFailure) {
          emit(Editing(input: event.input, fieldErrors: failure.fieldErrors));
        } else {
          emit(EventManagementFailure(failure.message));
        }
      },
    );
  }

  Future<void> _onStatusChangeRequested(
    StatusChangeRequested event,
    Emitter<EventManagementState> emit,
  ) async {
    final result = await _changeEventStatus(
      vendorId: event.vendorId,
      eventId: event.eventId,
      status: event.status,
    );

    result.fold(
      (Event _) {
        // The watch stream re-emits the updated event set; no extra state needed
        // beyond clearing any prior failure.
      },
      (core.Failure failure) => emit(EventManagementFailure(failure.message)),
    );
  }

  Future<void> _onVendorEventsWatchStarted(
    VendorEventsWatchStarted event,
    Emitter<EventManagementState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _watchVendorEvents(event.vendorId).listen(
      (List<Event> events) => add(_VendorEventsUpdated(events)),
    );
  }

  void _onVendorEventsUpdated(
    _VendorEventsUpdated event,
    Emitter<EventManagementState> emit,
  ) {
    emit(VendorEventsLoaded(event.events));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
