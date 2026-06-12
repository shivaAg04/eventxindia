import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/notification.dart';

/// Domain-owned boundary for the trusted notification capability (R13.1–R13.8).
///
/// Notification dispatch — Firebase Cloud Messaging delivery with retry, skip,
/// and failure handling — runs server-side behind this abstraction (today
/// Cloud Functions + FCM, later a Node.js worker + push provider). No backend
/// type ever crosses this boundary: every method speaks pure domain
/// [AppNotification] values and `Result<T, Failure>`.
///
/// This interface exposes only the **client/read** surface. Clients never
/// write delivery fields ([AppNotification.deliveryStatus],
/// [AppNotification.attemptCount]); those are advanced exclusively by the
/// trusted service. The client may observe the notifications addressed to a
/// recipient and register the device token that delivery targets.
abstract class NotificationService {
  /// Streams the notifications addressed to the user identified by
  /// [recipientId], most recent first.
  ///
  /// Recipients may read only their own notifications.
  Stream<List<AppNotification>> watchForRecipient(String recipientId);

  /// Registers the FCM [deviceToken] for the user identified by [userId] so
  /// that future notifications can be delivered to this device.
  ///
  /// When no token is registered, delivery for that recipient is skipped
  /// without raising an error (R13.7).
  Future<Result<Unit, Failure>> registerDeviceToken({
    required String userId,
    required String deviceToken,
  });

  /// Removes the FCM [deviceToken] for the user identified by [userId], e.g. on
  /// sign-out, so that notifications are no longer delivered to this device.
  Future<Result<Unit, Failure>> unregisterDeviceToken({
    required String userId,
    required String deviceToken,
  });
}
