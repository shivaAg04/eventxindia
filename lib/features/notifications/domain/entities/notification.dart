import 'package:equatable/equatable.dart';

import 'delivery_status.dart';
import 'notification_type.dart';

/// A push notification raised by a triggering domain event (application
/// created/decided, event reminder due) and dispatched by the trusted backend
/// `NotificationService` (R13.1–R13.8).
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only, so it is unaffected by a future change of backend. The
/// delivery-tracking fields ([deliveryStatus], [attemptCount]) act as
/// idempotency markers for the dispatch pipeline — a newly created
/// notification starts in [DeliveryStatus.pending] with an [attemptCount] of
/// `0`, and only the trusted service advances them (clients never write
/// delivery fields).
///
/// The [payload] holds the triggering event data (event/application ids plus a
/// display title and body). It is preserved verbatim even when delivery fails,
/// so a failed notification keeps the context needed to diagnose or replay it
/// (R13.8).
class AppNotification extends Equatable {
  const AppNotification({
    required this.notificationId,
    required this.recipientId,
    required this.type,
    required this.payload,
    required this.deliveryStatus,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
  });

  /// Creates a brand-new notification of [type] for [recipientId].
  ///
  /// The [deliveryStatus] is set to [DeliveryStatus.pending] and the
  /// [attemptCount] to `0`; the trusted backend service advances both as it
  /// attempts delivery. The [payload] carries the triggering event data and
  /// [createdAt] records when the notification was raised.
  factory AppNotification.create({
    required String notificationId,
    required String recipientId,
    required NotificationType type,
    required Map<String, Object?> payload,
    required DateTime createdAt,
  }) {
    return AppNotification(
      notificationId: notificationId,
      recipientId: recipientId,
      type: type,
      payload: Map<String, Object?>.unmodifiable(payload),
      deliveryStatus: DeliveryStatus.pending,
      attemptCount: 0,
      createdAt: createdAt,
    );
  }

  /// The unique identifier of this notification (the `notifications/{id}` key).
  final String notificationId;

  /// The id of the user this notification is addressed to.
  final String recipientId;

  /// The kind of notification, which determines its recipient and content.
  final NotificationType type;

  /// The triggering event data (e.g. `eventId`, `applicationId`, `title`,
  /// `body`), preserved verbatim across delivery attempts (R13.8).
  final Map<String, Object?> payload;

  /// The current delivery outcome of this notification.
  final DeliveryStatus deliveryStatus;

  /// The number of delivery attempts made so far, in the range `0..3`
  /// (R13.6).
  final int attemptCount;

  /// When this notification was created.
  final DateTime createdAt;

  /// When the most recent delivery attempt was made, or `null` before the
  /// first attempt.
  final DateTime? lastAttemptAt;

  /// Returns a copy of this notification with the given fields replaced.
  AppNotification copyWith({
    DeliveryStatus? deliveryStatus,
    int? attemptCount,
    DateTime? lastAttemptAt,
  }) {
    return AppNotification(
      notificationId: notificationId,
      recipientId: recipientId,
      type: type,
      payload: payload,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        notificationId,
        recipientId,
        type,
        payload,
        deliveryStatus,
        attemptCount,
        createdAt,
        lastAttemptAt,
      ];

  @override
  String toString() => 'AppNotification('
      'notificationId: $notificationId, '
      'recipientId: $recipientId, '
      'type: $type, '
      'payload: $payload, '
      'deliveryStatus: $deliveryStatus, '
      'attemptCount: $attemptCount, '
      'createdAt: $createdAt, '
      'lastAttemptAt: $lastAttemptAt)';
}
