import '../../../core/value_objects/event_status.dart';
import 'entities/event.dart';

/// Pure, in-memory filter and search selectors over lists of [Event]s.
///
/// These functions back the student discovery search (R8.3, R8.4), the
/// dashboard "active events" list (R4.1, R8.1), and the vendor "manage events"
/// list (R5.2). They are pure: no I/O, deterministic, and depend only on their
/// arguments, which keeps them straightforward to property-test.

/// Returns the [Event]s with status [EventStatus.active] whose [Event.title] or
/// [Event.location] label contains [query], ignoring letter case (R8.3).
///
/// Matching is case-insensitive and substring-based against both the title and
/// the location label. The [query] is trimmed before matching; a blank query
/// matches every active event. Only active events are ever returned, mirroring
/// the fact that discovery operates on the active set (R8.1). The input order
/// is preserved. When nothing matches, an empty list is returned, which the
/// presentation layer renders as a no-results indication (R8.4).
List<Event> searchActiveEvents(String query, List<Event> events) {
  final List<Event> active = filterActive(events);
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return active;
  }
  return active
      .where((Event event) =>
          event.title.toLowerCase().contains(needle) ||
          event.location.label.toLowerCase().contains(needle))
      .toList();
}

/// Returns only the [Event]s whose status is [EventStatus.active], preserving
/// input order (R4.1, R8.1).
List<Event> filterActive(List<Event> events) =>
    filterByStatus(events, EventStatus.active);

/// Returns only the [Event]s whose status equals [status], preserving input
/// order. Backs status-scoped dashboard/list views (R6.6, R8.1).
List<Event> filterByStatus(List<Event> events, EventStatus status) =>
    events.where((Event event) => event.status == status).toList();

/// Returns only the [Event]s owned by the vendor identified by [vendorId],
/// preserving input order. Backs the vendor "manage events" list (R5.2).
List<Event> filterByOwner(List<Event> events, String vendorId) =>
    events.where((Event event) => event.vendorId == vendorId).toList();

/// The orderings a list of events can be sorted by in the student's
/// active-events list.
enum EventSort {
  /// Soonest event date first.
  dateAsc,

  /// Latest event date first.
  dateDesc,

  /// Lowest pay-per-head first.
  payAsc,

  /// Highest pay-per-head first.
  payDesc,
}

/// Returns a new list containing [events] ordered by [sort].
///
/// Pure and non-mutating: the input list is copied before sorting. Date
/// orderings compare [Event.date]; pay orderings compare the integer minor
/// units of [Event.payPerHead], so the comparison is exact.
List<Event> sortEvents(List<Event> events, EventSort sort) {
  final List<Event> copy = List<Event>.of(events);
  switch (sort) {
    case EventSort.dateAsc:
      copy.sort((Event a, Event b) => a.date.compareTo(b.date));
    case EventSort.dateDesc:
      copy.sort((Event a, Event b) => b.date.compareTo(a.date));
    case EventSort.payAsc:
      copy.sort((Event a, Event b) =>
          a.payPerHead.minorUnits.compareTo(b.payPerHead.minorUnits));
    case EventSort.payDesc:
      copy.sort((Event a, Event b) =>
          b.payPerHead.minorUnits.compareTo(a.payPerHead.minorUnits));
  }
  return copy;
}

/// Returns the [events] whose [Event.date] falls within the inclusive
/// `[start, end]` calendar-day range, preserving input order.
///
/// Either bound may be `null` to leave that side open. Comparison is by
/// calendar day (time-of-day is ignored), so an event dated any time on [end]
/// still matches. A `null`/`null` range returns every event.
List<Event> filterByDateRange(
  List<Event> events, {
  DateTime? start,
  DateTime? end,
}) {
  final int? from = start == null ? null : _dayOrdinal(start);
  final int? to = end == null ? null : _dayOrdinal(end);
  return events.where((Event event) {
    final int day = _dayOrdinal(event.date);
    if (from != null && day < from) {
      return false;
    }
    if (to != null && day > to) {
      return false;
    }
    return true;
  }).toList();
}

/// Maps a [DateTime] to an integer day index (`YYYYMMDD`) so two dates on the
/// same calendar day compare equal regardless of their time component.
int _dayOrdinal(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
