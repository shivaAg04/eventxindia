import 'package:eventxindia/features/notifications/domain/entities/delivery_status.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationType wireName round-trips', () {
    test('parse(wireName) returns the original value for every type', () {
      for (final NotificationType type in NotificationType.values) {
        expect(NotificationTypeX.parse(type.wireName), type);
        expect(NotificationTypeX.tryParse(type.wireName), type);
      }
    });

    test('wire names match the design schema', () {
      expect(NotificationType.newApplication.wireName, 'NewApplication');
      expect(
        NotificationType.applicationApproved.wireName,
        'ApplicationApproved',
      );
      expect(
        NotificationType.applicationRejected.wireName,
        'ApplicationRejected',
      );
      expect(NotificationType.eventReminder.wireName, 'EventReminder');
    });

    test('parse throws on unknown input', () {
      expect(
        () => NotificationTypeX.parse('Bogus'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tryParse returns null on unknown input', () {
      expect(NotificationTypeX.tryParse('Bogus'), isNull);
    });
  });

  group('DeliveryStatus wireName round-trips', () {
    test('parse(wireName) returns the original value for every status', () {
      for (final DeliveryStatus status in DeliveryStatus.values) {
        expect(DeliveryStatusX.parse(status.wireName), status);
        expect(DeliveryStatusX.tryParse(status.wireName), status);
      }
    });

    test('wire names match the design schema', () {
      expect(DeliveryStatus.pending.wireName, 'Pending');
      expect(DeliveryStatus.delivered.wireName, 'Delivered');
      expect(DeliveryStatus.skipped.wireName, 'Skipped');
      expect(DeliveryStatus.failed.wireName, 'Failed');
    });

    test('parse throws on unknown input', () {
      expect(
        () => DeliveryStatusX.parse('Bogus'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tryParse returns null on unknown input', () {
      expect(DeliveryStatusX.tryParse('Bogus'), isNull);
    });
  });
}
