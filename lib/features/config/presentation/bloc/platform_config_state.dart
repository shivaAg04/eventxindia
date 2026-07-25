part of 'platform_config_cubit.dart';

/// State for the admin platform-settings screen.
sealed class PlatformConfigState extends Equatable {
  const PlatformConfigState();

  @override
  List<Object?> get props => <Object?>[];
}

/// The current commission percentage is being loaded.
class PlatformConfigLoading extends PlatformConfigState {
  const PlatformConfigLoading();
}

/// The current commission [percent] is available.
class PlatformConfigLoaded extends PlatformConfigState {
  const PlatformConfigLoaded(this.percent);

  final int percent;

  @override
  List<Object?> get props => <Object?>[percent];
}

/// The config could not be loaded.
class PlatformConfigFailure extends PlatformConfigState {
  const PlatformConfigFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
