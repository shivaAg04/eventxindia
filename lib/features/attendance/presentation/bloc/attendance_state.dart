part of 'attendance_bloc.dart';

/// Base type for all [AttendanceBloc] states rendered by the attendance
/// screens.
///
/// States are compared by [Equatable] so the widget layer rebuilds only on a
/// genuine state change and `bloc_test` can assert exact emission sequences.
sealed class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The idle/initial state: no check-in/out in flight (R10.1).
final class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

/// The device location is being acquired ahead of a check-in (R10.4).
///
/// Emitted immediately after [CheckInRequested]; if acquisition fails the bloc
/// transitions to [AttendanceFailure] without attempting the check-in.
final class LocatingDevice extends AttendanceState {
  const LocatingDevice();
}

/// A check-in is being validated and persisted (after the location was
/// acquired; R10.1–R10.3, R10.5).
final class CheckingIn extends AttendanceState {
  const CheckingIn();
}

/// A check-out is being validated and persisted (R10.6–R10.8).
final class CheckingOut extends AttendanceState {
  const CheckingOut();
}

/// Check-in succeeded; carries the persisted [record] (R10.1).
final class CheckedIn extends AttendanceState {
  const CheckedIn(this.record);

  /// The attendance record created at check-in.
  final AttendanceRecord record;

  @override
  List<Object?> get props => <Object?>[record];
}

/// Check-out succeeded; carries the completed [record] with working hours
/// (R10.6, R10.9).
final class CheckedOut extends AttendanceState {
  const CheckedOut(this.record);

  /// The completed attendance record after check-out.
  final AttendanceRecord record;

  @override
  List<Object?> get props => <Object?>[record];
}

/// A check-in or check-out was rejected; carries the [reason] so the screen can
/// surface the specific cause — an invalid code (R10.2, R10.7), an unavailable
/// or out-of-range location (R10.3, R10.4), an already-checked-in student
/// (R10.5), or a missing check-in (R10.8).
final class AttendanceFailure extends AttendanceState {
  const AttendanceFailure(this.reason);

  /// The failure describing why the action was rejected.
  final Failure reason;

  /// The human-readable message for display.
  String get message => reason.message;

  @override
  List<Object?> get props => <Object?>[reason];
}

/// The student's attendance history loaded from the repository stream (R4.4).
final class HistoryLoaded extends AttendanceState {
  const HistoryLoaded(this.records);

  /// The student's attendance records, most-recent ordering left to the source.
  final List<AttendanceRecord> records;

  @override
  List<Object?> get props => <Object?>[records];
}
