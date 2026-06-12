/// The working hours between [checkIn] and [checkOut], expressed in hours
/// rounded to two decimal places and never negative (R10.9).
///
/// This is the attendance domain's canonical working-hours function: the
/// check-out flow stores its result on the completed [AttendanceRecord]. It is
/// a pure function — no I/O, depends only on its arguments.
///
/// The duration is `checkOut - checkIn` expressed in hours. A non-positive
/// duration (equal timestamps, or a [checkOut] earlier than [checkIn]) is
/// clamped to `0.0` so the result is always non-negative. The hours are then
/// rounded to two decimal places (so e.g. `1.005 -> 1.01`, `0.0` for equal
/// times).
double workingHours(DateTime checkIn, DateTime checkOut) {
  final int micros = checkOut.difference(checkIn).inMicroseconds;
  if (micros <= 0) {
    return 0.0;
  }
  final double hours = micros / Duration.microsecondsPerHour;
  return (hours * 100).roundToDouble() / 100;
}
