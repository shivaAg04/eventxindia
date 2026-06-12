import 'package:equatable/equatable.dart';

/// Events accepted by the [EarningsBloc].
///
/// The earnings screen is read-only (R11.6): the only thing the user can do is
/// open it and observe the live projection, so there is a single event that
/// starts watching a student's estimated earnings stream.
sealed class EarningsEvent extends Equatable {
  const EarningsEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Starts watching the estimated earnings of the student identified by
/// [studentId].
///
/// Dispatched once when the earnings screen (or the dashboard earnings summary)
/// is opened (R4.5, R11.3). The bloc subscribes to [GetEarnings] and emits a
/// fresh state for every projection the stream yields.
final class EarningsWatchStarted extends EarningsEvent {
  /// Creates the event for the student whose earnings should be watched.
  const EarningsWatchStarted(this.studentId);

  /// The id of the student whose earnings stream should be observed.
  final String studentId;

  @override
  List<Object?> get props => <Object?>[studentId];
}
