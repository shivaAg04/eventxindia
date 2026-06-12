import '../features/admin/domain/repositories/admin_repository.dart';

/// Registers this device's FCM token for the signed-in user after
/// authentication (R13.7).
///
/// The trusted notification backend delivers push notifications to the device
/// tokens stored on each user. This registrar is the client-side half: once a
/// user is authenticated it obtains the device's current FCM token and writes
/// it through [AdminRepository.registerDeviceToken], so the backend can address
/// this device.
///
/// It is deliberately decoupled from Firebase types: the signed-in user's id
/// and the FCM token are supplied by injected providers ([uidProvider] /
/// [tokenProvider]), keeping this unit testable and letting the composition
/// root wire the real Firebase sources. Both the missing-user and missing-token
/// cases are guarded so registration is a no-op rather than an error when there
/// is nothing to register.
class DeviceTokenRegistrar {
  const DeviceTokenRegistrar({
    required this.adminRepository,
    required this.uidProvider,
    required this.tokenProvider,
  });

  /// The repository through which the token is persisted for the user (R13.7).
  final AdminRepository adminRepository;

  /// Resolves the signed-in user's id, or `null` when no user is signed in.
  final String? Function() uidProvider;

  /// Resolves the device's current FCM token, or `null` when unavailable.
  final Future<String?> Function() tokenProvider;

  /// Registers the current device token for the signed-in user, if both are
  /// available (R13.7).
  ///
  /// Returns `true` when a token was registered, and `false` when registration
  /// was skipped because there was no signed-in user or no token. Any
  /// persistence failure is swallowed: token registration is best-effort and
  /// must never block the post-authentication flow.
  Future<bool> register() async {
    final String? uid = uidProvider();
    if (uid == null || uid.isEmpty) {
      return false;
    }

    final String? token = await tokenProvider();
    if (token == null || token.isEmpty) {
      return false;
    }

    await adminRepository.registerDeviceToken(uid, token);
    return true;
  }
}
