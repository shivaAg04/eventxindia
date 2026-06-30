import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/event_status.dart';
import '../entities/event.dart';

/// Identifies which attendance code is being set on an event.
///
/// An event carries two independent codes: a [start] code used for check-in
/// (R10.2) and an [end] code used for check-out (R10.7). [EventRepository.setCode]
/// takes one of these to know which field to write.
enum EventCodeKind {
  /// The check-in (start) attendance code.
  start,

  /// The check-out (end) attendance code.
  end,
}

/// Abstract gateway for persisting and observing [Event] records.
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firestore, later a
/// REST/WebSocket backend) lives in the data layer. No backend types ever
/// cross this boundary — every method speaks pure domain [Event] values and
/// `Result<T, Failure>` (or streams of domain values).
abstract class EventRepository {
  /// Persists a newly created [event].
  ///
  /// The event is expected to be in [EventStatus.active] on creation (R7.6).
  /// Returns the stored event on success or a [Failure] on error.
  Future<Result<Event, Failure>> create(Event event);

  /// Streams every event currently in [EventStatus.active], independent of
  /// remaining slots, for student discovery (R8.1).
  Stream<List<Event>> watchActive();

  /// Streams the events owned by the vendor identified by [vendorId] for the
  /// vendor's Manage Events view (R5.2).
  Stream<List<Event>> watchByVendor(String vendorId);

  /// Returns the event identified by [eventId], or a [NotFoundFailure] when no
  /// such event exists (R8.5).
  Future<Result<Event, Failure>> getById(String eventId);

  /// Transitions the event identified by [eventId] to [status], returning the
  /// updated event (R7.5). Implementations must reject transitions that are not
  /// permitted with a [StateTransitionFailure].
  Future<Result<Event, Failure>> updateStatus(
    String eventId,
    EventStatus status,
  );

  /// Sets the attendance [code] of the given [kind] on the event identified by
  /// [eventId], returning the updated event (R5.6, R10.2, R10.7).
  Future<Result<Event, Failure>> setCode(
    String eventId,
    EventCodeKind kind,
    String code,
  );

  /// Sets the event's approved-applicant count to [approvedCount], returning the
  /// updated event. Used when a vendor approves an applicant to keep the
  /// remaining-seat count current and enforce capacity.
  Future<Result<Event, Failure>> setApprovedCount(
    String eventId,
    int approvedCount,
  );
}
