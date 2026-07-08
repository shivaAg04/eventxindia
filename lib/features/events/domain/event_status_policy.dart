import '../../../core/value_objects/event_status.dart';
import 'entities/event.dart';

/// Pure, backend-independent policy for deriving an event's *effective* status
/// from its scheduled [Event.date] relative to the current date.
///
/// An event whose date has passed is over, so it is treated as
/// [EventStatus.completed] even if its stored status is still
/// [EventStatus.active] (e.g. because no vendor/backend job has transitioned it
/// yet). This keeps past events out of the student's joinable "active" set and
/// lands them in the vendor's Closed/Completed view without requiring a
/// scheduled write. A vendor's deliberate [EventStatus.closed] is preserved.
///
/// Comparison is calendar-day based: an event is past when its date falls on an
/// earlier day than [now], regardless of the time of day.

/// Whether [date] falls on a calendar day strictly before [now], ignoring the
/// time of day. The single definition of "past by calendar day" reused wherever
/// an event's date must be classified as over — including application snapshots
/// that carry only an event date, not the full [Event].
bool isDatePast(DateTime date, DateTime now) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  return day.isBefore(today);
}

/// Whether [event] falls on a calendar day strictly before [now].
bool isEventPast(Event event, DateTime now) => isDatePast(event.date, now);

/// The status [event] should be presented with at [now].
///
/// Returns [EventStatus.completed] for a still-[EventStatus.active] event whose
/// date has passed; otherwise returns the event's stored [Event.status].
EventStatus effectiveEventStatus(Event event, DateTime now) {
  if (event.status == EventStatus.active && isEventPast(event, now)) {
    return EventStatus.completed;
  }
  return event.status;
}
