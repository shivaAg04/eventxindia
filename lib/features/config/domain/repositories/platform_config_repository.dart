import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';

/// The commission percentage applied by default when none is configured yet.
const int kDefaultCommissionPercent = 10;

/// The inclusive bounds for a valid commission percentage.
const int kMinCommissionPercent = 0;
const int kMaxCommissionPercent = 100;

/// Gateway for the platform-wide configuration the admin controls.
///
/// V1 holds a single tunable: the platform commission percentage the admin
/// takes on an event's earnings. It is a global current value — each event
/// **snapshots** the value in force at its creation, so changing it here never
/// affects past events (that snapshot lives on the event, not here).
///
/// No backend type crosses this boundary. When no value has ever been set the
/// repository reports [kDefaultCommissionPercent] (10).
abstract class PlatformConfigRepository {
  /// Streams the current commission percentage, emitting
  /// [kDefaultCommissionPercent] until/unless a value is configured.
  Stream<int> watchCommissionPercent();

  /// Reads the current commission percentage once (defaulting to
  /// [kDefaultCommissionPercent]).
  Future<Result<int, Failure>> getCommissionPercent();

  /// Sets the current commission percentage (admin only). Expected to be within
  /// [kMinCommissionPercent]..[kMaxCommissionPercent].
  Future<Result<Unit, Failure>> setCommissionPercent(int percent);
}
