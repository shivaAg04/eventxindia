part of 'attendance_bloc.dart';

/// Base type for all [AttendanceBloc] events (UI intents in the attendance
/// flow).
///
/// Events are pure value objects compared by [Equatable], so duplicate intents
/// are deduplicated by `bloc_test` and equality checks.
sealed class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Requests a check-in for [studentId] to the event identified by [eventId]
/// using the vendor's [startCode] (R10.1, R10.2).
///
/// The bloc acquires the device location itself (R10.4) before delegating to
/// [CheckIn]; the location is therefore *not* carried on the event.
final class CheckInRequested extends AttendanceEvent {
  const CheckInRequested({
    required this.studentId,
    required this.eventId,
    required this.startCode,
  });

  /// The id of the checking-in student.
  final String studentId;

  /// The id of the event being checked in to.
  final String eventId;

  /// The start code the student entered, validated by [CheckIn] (R10.2).
  final String startCode;

  @override
  List<Object?> get props => <Object?>[studentId, eventId, startCode];
}

/// Requests a check-out for [studentId] from the event identified by [eventId]
/// using the vendor's [endCode] (R10.6, R10.7).
final class CheckOutRequested extends AttendanceEvent {
  const CheckOutRequested({
    required this.studentId,
    required this.eventId,
    required this.endCode,
  });

  /// The id of the checking-out student.
  final String studentId;

  /// The id of the event being checked out of.
  final String eventId;

  /// The end code the student entered, validated by [CheckOut] (R10.7).
  final String endCode;

  @override
  List<Object?> get props => <Object?>[studentId, eventId, endCode];
}

/// Starts watching the attendance history of the student identified by
/// [studentId] so the bloc reflects records as they change (R4.4).
final class HistoryWatchStarted extends AttendanceEvent {
  const HistoryWatchStarted(this.studentId);

  /// The id of the student whose attendance history is watched.
  final String studentId;

  @override
  List<Object?> get props => <Object?>[studentId];
}
