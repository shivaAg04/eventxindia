import 'entities/event.dart';

/// Pure ownership guard for vendor-scoped event actions (R5.9).
///
/// Returns `true` when the vendor identified by [vendorId] owns [event], i.e.
/// when the event's [Event.vendorId] matches. Use cases that mutate or expose
/// an event on a vendor's behalf (status change, applicant list, attendance
/// view, attendance-code generation) call this before acting and reject with an
/// `AuthorizationFailure` when it returns `false`.
///
/// This is a pure function: no I/O, depends only on its arguments.
bool ownsEvent(String vendorId, Event event) => event.vendorId == vendorId;
