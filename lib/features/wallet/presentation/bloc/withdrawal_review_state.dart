part of 'withdrawal_review_cubit.dart';

/// Base type for every state emitted by [WithdrawalReviewCubit].
sealed class WithdrawalReviewState extends Equatable {
  const WithdrawalReviewState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The first list emission has not arrived yet.
class WithdrawalReviewLoading extends WithdrawalReviewState {
  const WithdrawalReviewLoading();
}

/// The current set of withdrawal requests across all students.
class WithdrawalReviewLoaded extends WithdrawalReviewState {
  const WithdrawalReviewLoaded(this.requests);

  final List<WithdrawalRequest> requests;

  @override
  List<Object?> get props => <Object?>[requests];
}

/// The stream errored (R4.7).
class WithdrawalReviewFailure extends WithdrawalReviewState {
  const WithdrawalReviewFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
