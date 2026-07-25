part of 'wallet_cubit.dart';

/// Base type for every state emitted by [WalletCubit].
sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The wallet is still loading its first earnings/withdrawals emissions.
class WalletLoading extends WalletState {
  const WalletLoading();
}

/// The composed wallet projection with derived balances.
class WalletLoaded extends WalletState {
  const WalletLoaded(this.wallet);

  final Wallet wallet;

  @override
  List<Object?> get props => <Object?>[wallet];
}

/// One of the underlying streams errored (R4.7).
class WalletFailure extends WalletState {
  const WalletFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
