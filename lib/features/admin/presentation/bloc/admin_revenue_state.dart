part of 'admin_revenue_cubit.dart';

/// Base type for every state emitted by [AdminRevenueCubit].
sealed class AdminRevenueState extends Equatable {
  const AdminRevenueState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Waiting for the first events/attendance emissions.
class RevenueLoading extends AdminRevenueState {
  const RevenueLoading();
}

/// The composed revenue summary.
class RevenueLoaded extends AdminRevenueState {
  const RevenueLoaded(this.summary);

  final RevenueSummary summary;

  @override
  List<Object?> get props => <Object?>[
        summary.completedEventCount,
        summary.revenue,
        summary.distributed,
        summary.platformShare,
        summary.studentsEarnedAll,
      ];
}

/// One of the underlying streams errored.
class RevenueFailure extends AdminRevenueState {
  const RevenueFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
