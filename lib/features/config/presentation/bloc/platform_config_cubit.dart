import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/usecases/set_commission_percent.dart';
import '../../domain/usecases/watch_commission_percent.dart';

part 'platform_config_state.dart';

/// Drives the admin platform-settings screen: watches the current commission
/// percentage and applies changes.
@injectable
class PlatformConfigCubit extends Cubit<PlatformConfigState> {
  PlatformConfigCubit(this._watch, this._set)
      : super(const PlatformConfigLoading());

  final WatchCommissionPercent _watch;
  final SetCommissionPercent _set;

  StreamSubscription<int>? _sub;

  /// Starts watching the current commission percentage.
  void watch() {
    _sub?.cancel();
    _sub = _watch().listen(
      (int percent) => emit(PlatformConfigLoaded(percent)),
      onError: (Object error, StackTrace _) =>
          emit(PlatformConfigFailure(error.toString())),
    );
  }

  /// Applies [percent] as the new commission percentage. Returns the result so
  /// the screen can confirm or surface the validation error; the watch stream
  /// updates the displayed value on success.
  Future<Result<Unit, Failure>> setPercent(int percent) => _set(percent);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
