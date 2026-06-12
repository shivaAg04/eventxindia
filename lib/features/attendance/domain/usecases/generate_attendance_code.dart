import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/event_ownership.dart';
import '../../../events/domain/repositories/event_repository.dart';

/// Generates and stores an attendance code (start or end) for an event on
/// behalf of the owning vendor (R5.6, R5.9).
///
/// Code generation is supplied as an injected [generateCode] function so the
/// use case stays pure and deterministic under test: production wiring passes a
/// secure random generator, while tests pass a fixed value. The generated code
/// is associated with the event via [EventRepository.setCode] under the given
/// [EventCodeKind] (R5.6).
///
/// The flow is:
/// 1. Load the event by [eventId]; a missing event yields the repository's
///    failure (typically a [NotFoundFailure]).
/// 2. Authorize: the requesting [vendorId] must own the event, otherwise the
///    action is denied with an [AuthorizationFailure] and no code is generated
///    (R5.9).
/// 3. Generate a code and persist it via [EventRepository.setCode] for the
///    requested [kind] (R5.6).
///
/// This is pure domain logic: it depends only on the abstract
/// [EventRepository] and the injected generator, never on any backend type.
class GenerateAttendanceCode {
  /// Creates the use case with its injected [EventRepository] and the
  /// [generateCode] function used to produce a new attendance code.
  const GenerateAttendanceCode({
    required EventRepository eventRepository,
    required String Function() generateCode,
  })  : _eventRepository = eventRepository,
        _generateCode = generateCode;

  final EventRepository _eventRepository;
  final String Function() _generateCode;

  /// Generates and stores a [kind] attendance code for the event identified by
  /// [eventId] on behalf of [vendorId].
  ///
  /// Returns the generated code on success, or a [Failure] when the event does
  /// not exist or the vendor does not own it (R5.9).
  Future<Result<String, Failure>> call({
    required String vendorId,
    required String eventId,
    required EventCodeKind kind,
  }) async {
    final Result<Event, Failure> eventResult =
        await _eventRepository.getById(eventId);

    final Event? event = eventResult.valueOrNull;
    if (event == null) {
      return Result<String, Failure>.err(
        eventResult.failureOrNull ?? const NotFoundFailure(),
      );
    }

    if (!ownsEvent(vendorId, event)) {
      return const Result<String, Failure>.err(
        AuthorizationFailure(
          message: 'You are not authorized to generate codes for this event.',
        ),
      );
    }

    final String code = _generateCode();
    final Result<Event, Failure> setResult =
        await _eventRepository.setCode(eventId, kind, code);

    return setResult.map<String>((Event _) => code);
  }
}
