import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/geo_point.dart';

/// The maximum time, in seconds, allowed to acquire a device location before
/// the attempt is abandoned and surfaced as a [LocationFailure] (R10.4).
const Duration kLocationTimeout = Duration(seconds: 30);

/// Acquires the device's current geographic location for attendance check-in.
///
/// This is the presentation-layer seam between the pure [CheckIn] use case —
/// which takes the acquired location as a `Result<GeoPoint, Failure>` and owns
/// no platform APIs — and the device's GPS hardware. The [AttendanceBloc] calls
/// [currentLocation] while in the `LocatingDevice` state and forwards the
/// returned result straight into the use case.
///
/// Implementations must enforce the 30-second acquisition budget (R10.4): a
/// timeout, a disabled location service, or a denied permission all resolve to
/// an `Err(LocationFailure)` so the use case can reject the check-in with a
/// "location unavailable" reason rather than blocking the UI.
abstract class DeviceLocationService {
  /// Acquires the current device location, resolving to an `Ok(GeoPoint)` on
  /// success or an `Err(LocationFailure)` when the location cannot be obtained
  /// within [kLocationTimeout] or the necessary permissions are unavailable.
  Future<Result<GeoPoint, Failure>> currentLocation();
}

/// A [DeviceLocationService] backed by the `geolocator` plugin.
///
/// It verifies the location service is enabled and the permission is granted,
/// then requests a single high-accuracy fix bounded by [kLocationTimeout].
/// Every platform error — a disabled service, a denied/permanently-denied
/// permission, or a timeout — is mapped to a [LocationFailure] value so the
/// caller never has to catch an exception.
@Injectable(as: DeviceLocationService)
class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<Result<GeoPoint, Failure>> currentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Result<GeoPoint, Failure>.err(
          LocationFailure(
            message: 'Location services are turned off. Please enable them to '
                'check in.',
          ),
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const Result<GeoPoint, Failure>.err(
          LocationFailure(
            message: 'Location permission is required to check in.',
          ),
        );
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: kLocationTimeout,
        ),
      );

      return Result<GeoPoint, Failure>.ok(
        GeoPoint(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on TimeoutException {
      // R10.4: a location not obtained within the budget is unavailable.
      return const Result<GeoPoint, Failure>.err(
        LocationFailure(
          message: 'Your device location is unavailable. Please try again.',
        ),
      );
    } on Object {
      // Any other platform error (e.g. a sudden service failure) is treated as
      // an unavailable location rather than crashing the check-in flow.
      return const Result<GeoPoint, Failure>.err(
        LocationFailure(
          message: 'Your device location is unavailable. Please try again.',
        ),
      );
    }
  }
}
