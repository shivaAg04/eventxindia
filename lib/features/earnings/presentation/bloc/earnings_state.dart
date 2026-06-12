import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/money.dart';

/// States emitted by the [EarningsBloc].
///
/// Models the lifecycle of observing a student's estimated earnings: an initial
/// loading phase, then either a populated projection ([EarningsLoaded]) or an
/// empty one ([EarningsEmpty]), and a failure state if the stream errors
/// (R4.7).
sealed class EarningsState extends Equatable {
  const EarningsState();

  @override
  List<Object?> get props => <Object?>[];
}

/// The earnings projection has not been received yet.
///
/// Emitted immediately when watching starts, before the first value arrives
/// from the stream.
final class EarningsLoading extends EarningsState {
  /// Creates the loading state.
  const EarningsLoading();
}

/// The student has accrued earnings for one or more completed events.
///
/// Carries the monetary [total] (R11.3) and the per-event credited amounts in
/// [perEvent], keyed by event id (R11.4).
final class EarningsLoaded extends EarningsState {
  /// Creates a loaded state from the [total] and [perEvent] projection.
  const EarningsLoaded({required this.total, required this.perEvent});

  /// The estimated earnings total — the sum of every value in [perEvent].
  final Money total;

  /// The amount credited for each completed event, keyed by event id.
  final Map<String, Money> perEvent;

  @override
  List<Object?> get props => <Object?>[total, perEvent];
}

/// The student has no completed attendance records.
///
/// Represents a zero total and an empty per-event list (R11.5). Kept distinct
/// from [EarningsLoaded] so the screen can render a dedicated empty state.
final class EarningsEmpty extends EarningsState {
  /// Creates the empty state.
  const EarningsEmpty();
}

/// Watching the earnings stream failed.
///
/// Emitted when the underlying stream errors so the screen can show that the
/// data could not be loaded (R4.7).
final class EarningsFailure extends EarningsState {
  /// Creates a failure state with a human-readable [message].
  const EarningsFailure(this.message);

  /// A description of what went wrong, suitable for display.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
