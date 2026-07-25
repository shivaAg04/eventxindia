import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../config/domain/repositories/platform_config_repository.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../entities/event.dart';
import '../entities/event_location.dart';
import '../repositories/event_repository.dart';
import '../validators/event_validators.dart';

/// Creates a new [Event] on behalf of a [Vendor] (R2.10, R5.1, R7.1–R7.4,
/// R7.6).
///
/// The flow is:
/// 1. Authorize: the [vendor] must be [ApprovalStatus.approved], otherwise the
///    use case short-circuits with an [AuthorizationFailure] and nothing is
///    persisted (R2.10, R5.1).
/// 2. Validate the [EventInput] with [validateEvent]. Any failure short-circuits
///    with a [ValidationFailure] carrying the exact set of field errors so the
///    presentation layer can highlight them while retaining the user's input
///    (R7.2, R7.3).
/// 3. Build the [Event] in [EventStatus.active] (R7.4) but
///    [ApprovalStatus.pending] — an event is **not published** until an admin
///    approves it, so it stays out of student discovery until then — and
///    persist it via [EventRepository.create] (R7.6).
///
/// This use case depends only on the abstract [EventRepository], so it is
/// unaffected by the choice of backend.
class CreateEvent {
  const CreateEvent({
    required EventRepository repository,
    required PlatformConfigRepository configRepository,
  })  : _repository = repository,
        _configRepository = configRepository;

  final EventRepository _repository;
  final PlatformConfigRepository _configRepository;

  /// Authorizes, validates, then creates the event.
  ///
  /// [eventId] is the identifier for the new event (the persistence document
  /// id). [now] is the reference instant used both to validate the date and to
  /// stamp the created event.
  Future<Result<Event, Failure>> call({
    required Vendor vendor,
    required String eventId,
    required EventInput input,
    required DateTime now,
  }) async {
    if (vendor.approvalStatus != ApprovalStatus.approved) {
      return const Result<Event, Failure>.err(
        AuthorizationFailure(
          message: 'Only approved vendors can create events.',
        ),
      );
    }

    final List<FieldError> fieldErrors = validateEvent(input, now: now);
    if (fieldErrors.isNotEmpty) {
      return Result<Event, Failure>.err(
        ValidationFailure(fieldErrors: fieldErrors),
      );
    }

    // Snapshot the platform commission rate in force *now* onto the event, so a
    // later change to the platform-wide rate never affects this event. A read
    // failure falls back to the default (the repository already defaults), so
    // creation is never blocked by config being unavailable.
    final Result<int, Failure> percentResult =
        await _configRepository.getCommissionPercent();
    final int commissionPercent =
        percentResult.valueOrNull ?? kDefaultCommissionPercent;

    // Safe: validation above guarantees presence and structural validity of
    // every field used to build the event.
    final Event event = Event(
      eventId: eventId,
      vendorId: vendor.uid,
      title: input.title,
      description: input.description,
      date: input.date!,
      startTime: input.startTime!,
      endTime: input.endTime!,
      location: EventLocation(label: input.locationLabel, geo: input.geo!),
      slots: input.slots!,
      payPerHead: input.payPerHead!,
      status: EventStatus.active,
      // Not published until an admin approves — kept out of student discovery.
      approvalStatus: ApprovalStatus.pending,
      createdAt: now,
      updatedAt: now,
      platformCommissionPercent: commissionPercent,
    );

    return _repository.create(event);
  }
}
