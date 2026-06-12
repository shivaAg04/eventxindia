import 'package:eventxindia/features/notifications/domain/entities/delivery_status.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2024, 1, 1, 12);

  group('AppNotification.create', () {
    test('starts Pending with attemptCount 0 and no lastAttemptAt', () {
      final AppNotification notification = AppNotification.create(
        notificationId: 'n1',
        recipientId: 'vendor-1',
        type: NotificationType.newApplication,
        payload: <String, Object?>{
          'eventId': 'e1',
          'applicationId': 'e1_s1',
          'title': 'New application',
          'body': 'A student applied to your event.',
        },
        createdAt: now,
      );

      expect(notification.deliveryStatus, DeliveryStatus.pending);
      expect(notification.attemptCount, 0);
      expect(notification.lastAttemptAt, isNull);
      expect(notification.recipientId, 'vendor-1');
      expect(notification.type, NotificationType.newApplication);
      expect(notification.payload['eventId'], 'e1');
    });

    test('payload is unmodifiable so triggering data is preserved', () {
      final AppNotification notification = AppNotification.create(
        notificationId: 'n1',
        recipientId: 'student-1',
        type: NotificationType.applicationApproved,
        payload: <String, Object?>{'title': 'Approved', 'body': 'Congrats'},
        createdAt: now,
      );

      expect(
        () => notification.payload['title'] = 'tampered',
        throwsUnsupportedError,
      );
    });
  });

  group('copyWith', () {
    test('advances delivery fields while preserving identity and payload', () {
      final AppNotification pending = AppNotification.create(
        notificationId: 'n1',
        recipientId: 'student-1',
        type: NotificationType.eventReminder,
        payload: <String, Object?>{'eventId': 'e1', 'title': 'T', 'body': 'B'},
        createdAt: now,
      );

      final DateTime attemptedAt = now.add(const Duration(seconds: 10));
      final AppNotification delivered = pending.copyWith(
        deliveryStatus: DeliveryStatus.delivered,
        attemptCount: 1,
        lastAttemptAt: attemptedAt,
      );

      expect(delivered.deliveryStatus, DeliveryStatus.delivered);
      expect(delivered.attemptCount, 1);
      expect(delivered.lastAttemptAt, attemptedAt);
      // Identity and triggering data unchanged.
      expect(delivered.notificationId, pending.notificationId);
      expect(delivered.recipientId, pending.recipientId);
      expect(delivered.type, pending.type);
      expect(delivered.payload, pending.payload);
      expect(delivered.createdAt, pending.createdAt);
    });

    test('returns an equal value when no fields are provided', () {
      final AppNotification original = AppNotification.create(
        notificationId: 'n1',
        recipientId: 'student-1',
        type: NotificationType.applicationRejected,
        payload: <String, Object?>{'title': 'T', 'body': 'B'},
        createdAt: now,
      );

      expect(original.copyWith(), original);
    });
  });

  group('value equality', () {
    test('two notifications with identical fields are equal', () {
      final AppNotification a = AppNotification.create(
        notificationId: 'n1',
        recipientId: 'student-1',
        type: NotificationType.applicationApproved,
        payload: <String, Object?>{'title': 'T', 'body': 'B'},
        createdAt: now,
      );
      final AppNotification b = AppNotification.create(
        notificationId: 'n1',
        recipientId: 'student-1',
        type: NotificationType.applicationApproved,
        payload: <String, Object?>{'title': 'T', 'body': 'B'},
        createdAt: now,
      );

      expect(a, b);
    });
  });
}
