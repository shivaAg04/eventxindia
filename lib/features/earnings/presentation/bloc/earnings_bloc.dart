import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/value_objects/money.dart';
import '../../domain/entities/earnings.dart';
import '../../domain/usecases/get_earnings.dart';
import 'earnings_event.dart';
import 'earnings_state.dart';

/// Presentation state holder for a student's estimated earnings.
///
/// Subscribes to [GetEarnings] when [EarningsWatchStarted] is dispatched and
/// maps each emitted [Earnings] projection onto a presentation state:
/// [EarningsEmpty] when the student has no completed attendance records
/// (zero total and empty per-event map, R11.5), otherwise [EarningsLoaded]
/// carrying the monetary total (R11.3) and per-event credited amounts (R11.4).
/// A stream error becomes [EarningsFailure] so the UI can report that earnings
/// could not be loaded (R4.7).
///
/// The bloc depends only on the [GetEarnings] use case (the dependency rule:
/// presentation → domain), never on a repository or any backend type.
@injectable
class EarningsBloc extends Bloc<EarningsEvent, EarningsState> {
  /// Creates the bloc over the injected [GetEarnings] use case.
  EarningsBloc(this._getEarnings) : super(const EarningsLoading()) {
    on<EarningsWatchStarted>(_onWatchStarted);
  }

  final GetEarnings _getEarnings;

  Future<void> _onWatchStarted(
    EarningsWatchStarted event,
    Emitter<EarningsState> emit,
  ) async {
    emit(const EarningsLoading());
    await emit.forEach<Earnings>(
      _getEarnings(studentId: event.studentId),
      onData: _stateFor,
      onError: (error, _) => EarningsFailure(error.toString()),
    );
  }

  /// Maps an [Earnings] projection onto the matching presentation state.
  ///
  /// A zero total with no per-event entries is the empty projection (R11.5);
  /// anything else carries its total and per-event credits (R11.3, R11.4).
  EarningsState _stateFor(Earnings earnings) {
    if (earnings.total == Money.zero && earnings.perEvent.isEmpty) {
      return const EarningsEmpty();
    }
    return EarningsLoaded(
      total: earnings.total,
      perEvent: earnings.perEvent,
    );
  }
}
