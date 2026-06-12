import '../../../../core/error/failure.dart';
import '../../../../core/value_objects/geo_point.dart';
import '../../../../core/value_objects/money.dart';
import '../entities/event.dart';
import '../entities/event_location.dart';

/// The raw, pre-persistence input for creating an [Event].
///
/// This is a pure domain value used by [validateEvent] and the `CreateEvent`
/// use case. Fields the user may have left unset are nullable so the validator
/// can report them as missing (R7.1, R7.2). Numeric fields ([slots],
/// [payPerHead]) are carried in a form that *can* hold out-of-range values so
/// the validator can range-check them (R7.3):
///
/// * [payPerHead] is a [Money] constructed without the pay-per-head range
///   constraint (`requirePayPerHeadRange: false`), so a `0` or an over-large
///   amount can reach the validator and be reported rather than throwing at
///   construction.
/// * [geo] is the location coordinate paired with [locationLabel]; the label's
///   1..200 character bound is checked here before an [EventLocation] is built.
class EventInput {
  const EventInput({
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.locationLabel,
    required this.geo,
    required this.slots,
    required this.payPerHead,
  });

  /// The event title; required, 1..[Event.maxTitleLength] characters (R7.1).
  final String title;

  /// The event description; required, 1..[Event.maxDescriptionLength]
  /// characters (R7.1).
  final String description;

  /// The calendar date of the event; `null` when not yet chosen. Must be the
  /// current date or a future date (R7.3).
  final DateTime? date;

  /// The scheduled start time; `null` when not yet chosen (R7.1).
  final DateTime? startTime;

  /// The scheduled end time; `null` when not yet chosen. Must be later than
  /// [startTime] (R7.3).
  final DateTime? endTime;

  /// The location label; required, 1..[EventLocation.maxLabelLength]
  /// characters (R7.1).
  final String locationLabel;

  /// The location coordinate; `null` when not yet chosen.
  final GeoPoint? geo;

  /// The number of available slots; `null` when not yet provided. Must be an
  /// integer within [Event.minSlots]..[Event.maxSlots] (R7.1, R7.3).
  final int? slots;

  /// The pay-per-head amount; `null` when not yet provided. Must be within
  /// `0.01 .. 9999999.99` (R7.1, R7.3).
  final Money? payPerHead;
}

/// The canonical field names used in [FieldError]s so the presentation layer
/// can map each error back to the form field that produced it.
abstract final class EventFields {
  static const String title = 'title';
  static const String description = 'description';
  static const String date = 'date';
  static const String startTime = 'startTime';
  static const String endTime = 'endTime';
  static const String location = 'location';
  static const String slots = 'slots';
  static const String payPerHead = 'payPerHead';
}

/// Validates an [Event] creation [input] against the presence and value-range
/// rules of R7.1–R7.3, returning the exact set of [FieldError]s.
///
/// An empty list means the input is valid. This is a pure function: it performs
/// no I/O and depends only on its arguments. [now] is the reference instant
/// used to verify that [EventInput.date] is the current or a future calendar
/// date (comparison is date-only, ignoring the time-of-day component).
///
/// The checks performed:
/// * Title present and 1..[Event.maxTitleLength] characters.
/// * Description present and 1..[Event.maxDescriptionLength] characters.
/// * Date present and not before today's calendar date.
/// * Start time present.
/// * End time present and strictly later than the start time.
/// * Location label present and 1..[EventLocation.maxLabelLength] characters,
///   plus a location coordinate.
/// * Slots present and within [Event.minSlots]..[Event.maxSlots].
/// * Pay-per-head present and within `0.01 .. 9999999.99`.
List<FieldError> validateEvent(
  EventInput input, {
  required DateTime now,
}) {
  final List<FieldError> errors = <FieldError>[];

  if (input.title.trim().isEmpty) {
    errors.add(const FieldError(
      field: EventFields.title,
      message: 'Title is required.',
    ));
  } else if (input.title.length > Event.maxTitleLength) {
    errors.add(const FieldError(
      field: EventFields.title,
      message: 'Title must be at most ${Event.maxTitleLength} characters.',
    ));
  }

  if (input.description.trim().isEmpty) {
    errors.add(const FieldError(
      field: EventFields.description,
      message: 'Description is required.',
    ));
  } else if (input.description.length > Event.maxDescriptionLength) {
    errors.add(const FieldError(
      field: EventFields.description,
      message: 'Description must be at most '
          '${Event.maxDescriptionLength} characters.',
    ));
  }

  final DateTime? date = input.date;
  if (date == null) {
    errors.add(const FieldError(
      field: EventFields.date,
      message: 'Date is required.',
    ));
  } else {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime eventDay = DateTime(date.year, date.month, date.day);
    if (eventDay.isBefore(today)) {
      errors.add(const FieldError(
        field: EventFields.date,
        message: 'Date must be the current date or a future date.',
      ));
    }
  }

  final DateTime? startTime = input.startTime;
  if (startTime == null) {
    errors.add(const FieldError(
      field: EventFields.startTime,
      message: 'Start time is required.',
    ));
  }

  final DateTime? endTime = input.endTime;
  if (endTime == null) {
    errors.add(const FieldError(
      field: EventFields.endTime,
      message: 'End time is required.',
    ));
  } else if (startTime != null && !endTime.isAfter(startTime)) {
    errors.add(const FieldError(
      field: EventFields.endTime,
      message: 'End time must be later than the start time.',
    ));
  }

  final String label = input.locationLabel.trim();
  if (label.isEmpty) {
    errors.add(const FieldError(
      field: EventFields.location,
      message: 'Location is required.',
    ));
  } else if (label.length > EventLocation.maxLabelLength) {
    errors.add(const FieldError(
      field: EventFields.location,
      message: 'Location must be at most '
          '${EventLocation.maxLabelLength} characters.',
    ));
  } else if (input.geo == null) {
    errors.add(const FieldError(
      field: EventFields.location,
      message: 'A location coordinate is required.',
    ));
  }

  final int? slots = input.slots;
  if (slots == null) {
    errors.add(const FieldError(
      field: EventFields.slots,
      message: 'Slots are required.',
    ));
  } else if (slots < Event.minSlots || slots > Event.maxSlots) {
    errors.add(const FieldError(
      field: EventFields.slots,
      message: 'Slots must be between '
          '${Event.minSlots} and ${Event.maxSlots}.',
    ));
  }

  final Money? payPerHead = input.payPerHead;
  if (payPerHead == null) {
    errors.add(const FieldError(
      field: EventFields.payPerHead,
      message: 'Pay per head is required.',
    ));
  } else if (payPerHead.minorUnits < Money.minPayPerHeadMinorUnits ||
      payPerHead.minorUnits > Money.maxPayPerHeadMinorUnits) {
    errors.add(const FieldError(
      field: EventFields.payPerHead,
      message: 'Pay per head must be between 0.01 and 9999999.99.',
    ));
  }

  return errors;
}
