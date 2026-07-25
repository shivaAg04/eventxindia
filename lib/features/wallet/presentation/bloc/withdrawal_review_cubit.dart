import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/usecases/decide_withdrawal.dart';
import '../../domain/usecases/watch_all_withdrawals.dart';

part 'withdrawal_review_state.dart';

/// Drives the admin's withdrawal-review tab (R11 wallet).
///
/// Streams every withdrawal request across all students and exposes [decide]
/// to approve/reject one; the stream re-emits after a decision so the list
/// updates itself.
@injectable
class WithdrawalReviewCubit extends Cubit<WithdrawalReviewState> {
  WithdrawalReviewCubit(this._watchAll, this._decide)
      : super(const WithdrawalReviewLoading());

  final WatchAllWithdrawals _watchAll;
  final DecideWithdrawal _decide;

  StreamSubscription<List<WithdrawalRequest>>? _sub;

  /// Starts watching every withdrawal request.
  void watch() {
    emit(const WithdrawalReviewLoading());
    _sub?.cancel();
    _sub = _watchAll().listen(
      (List<WithdrawalRequest> requests) =>
          emit(WithdrawalReviewLoaded(requests)),
      onError: (Object error, StackTrace _) =>
          emit(WithdrawalReviewFailure(error.toString())),
    );
  }

  /// Approves or rejects the request [id]. Returns the result so the screen can
  /// report failures; the list updates via the stream on success.
  Future<Result<Unit, Failure>> decide(String id, WithdrawalDecision decision) {
    return _decide(withdrawalId: id, decision: decision);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
