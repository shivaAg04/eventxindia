import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/delivery_status.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/notification_type.dart';

/// Firestore DTO for the `notifications/{notificationId}` collection (R13.5).
///
/// Bridges the pure [AppNotification] domain entity and its Firestore document
/// shape. All Firebase types (`Timestamp`, `DocumentSnapshot`) are confined to
/// this DTO: [fromFirestore] decodes a raw document into a [AppNotification]
/// (mapping `type`/`deliveryStatus` wire strings, the `payload` map, the
/// integer `attemptCount`, and `Timestamp` ↔ `DateTime`), and [toFirestore]
/// encodes the entity back. Clients only ever read this collection — delivery
/// fields are written exclusively by the trusted backend — but [toFirestore]
/// is provided for completeness and tests.
class NotificationDto {
  const NotificationDto({
    required this.notificationId,
    required this.recipientId,
    required this.type,
    required this.payload,
    required this.deliveryStatus,
    required this.attemptCount,
    required this.createdAt,
    this.lastAttemptAt,
  });

  /// Builds a DTO from a domain [AppNotification].
  factory NotificationDto.fromEntity(AppNotification entity) {
    return NotificationDto(
      notificationId: entity.notificationId,
      recipientId: entity.recipientId,
      type: entity.type.wireName,
      payload: Map<String, Object?>.from(entity.payload),
      deliveryStatus: entity.deliveryStatus.wireName,
      attemptCount: entity.attemptCount,
      createdAt: entity.createdAt,
      lastAttemptAt: entity.lastAttemptAt,
    );
  }

  /// Builds a DTO from a Firestore document snapshot.
  factory NotificationDto.fromFirestore(
    DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Notification ${doc.id} has no data');
    }
    final lastAttempt = data['lastAttemptAt'];
    return NotificationDto(
      notificationId: (data['notificationId'] as String?) ?? doc.id,
      recipientId: data['recipientId'] as String,
      type: data['type'] as String,
      payload: _payload(data['payload']),
      deliveryStatus: data['deliveryStatus'] as String,
      attemptCount: (data['attemptCount'] as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastAttemptAt:
          lastAttempt is Timestamp ? lastAttempt.toDate() : null,
    );
  }

  /// The `notifications/{id}` document key.
  final String notificationId;

  /// The id of the recipient user.
  final String recipientId;

  /// The notification type wire string (e.g. `"NewApplication"`).
  final String type;

  /// The triggering event payload, preserved verbatim (R13.8).
  final Map<String, Object?> payload;

  /// The delivery status wire string (e.g. `"Pending"`).
  final String deliveryStatus;

  /// The number of delivery attempts so far, `0..3` (R13.6).
  final int attemptCount;

  /// When the notification was created.
  final DateTime createdAt;

  /// When the most recent delivery attempt was made, or `null`.
  final DateTime? lastAttemptAt;

  /// Converts this DTO into a pure [AppNotification] domain entity.
  AppNotification toEntity() {
    return AppNotification(
      notificationId: notificationId,
      recipientId: recipientId,
      type: NotificationTypeX.parse(type),
      payload: Map<String, Object?>.unmodifiable(payload),
      deliveryStatus: DeliveryStatusX.parse(deliveryStatus),
      attemptCount: attemptCount,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt,
    );
  }

  /// Converts this DTO into a Firestore document map.
  Map<String, Object?> toFirestore() {
    return <String, Object?>{
      'notificationId': notificationId,
      'recipientId': recipientId,
      'type': type,
      'payload': payload,
      'deliveryStatus': deliveryStatus,
      'attemptCount': attemptCount,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastAttemptAt != null)
        'lastAttemptAt': Timestamp.fromDate(lastAttemptAt!),
    };
  }

  static Map<String, Object?> _payload(Object? value) {
    if (value == null) {
      return const <String, Object?>{};
    }
    return Map<String, Object?>.from(value as Map<Object?, Object?>);
  }
}
