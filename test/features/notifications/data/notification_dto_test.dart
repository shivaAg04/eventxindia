import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventxindia/features/notifications/data/dtos/notification_dto.dart';
import 'package:eventxindia/features/notifications/domain/entities/delivery_status.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDoc extends Mock
    implements DocumentSnapshot<Map<String, Object?>> {}

void main() {
  group('NotificationDto', () {
    final DateTime createdAt = DateTime(2025, 1, 2, 10, 30);
    final DateTime lastAttemptAt = DateTime(2025, 1, 2, 11);

    Map<String, Object?> sampleData() => <String, Object?>{
          'notificationId': 'n1',
          'recipientId': 'vendor-1',
          'type': 'NewApplication',
          'payload': <String, Object?>{
            'eventId': 'e1',
            'applicationId': 'a1',
            'title': 'New application',
            'body': 'A student applied',
          },
          'deliveryStatus': 'Delivered',
          'attemptCount': 1,
          'createdAt': Timestamp.fromDate(createdAt),
          'lastAttemptAt': Timestamp.fromDate(lastAttemptAt),
        };

    test('fromFirestore maps wire fields to the domain entity', () {
      final doc = _MockDoc();
      when(() => doc.id).thenReturn('n1');
      when(doc.data).thenReturn(sampleData());

      final AppNotification entity =
          NotificationDto.fromFirestore(doc).toEntity();

      expect(entity.notificationId, 'n1');
      expect(entity.recipientId, 'vendor-1');
      expect(entity.type, NotificationType.newApplication);
      expect(entity.deliveryStatus, DeliveryStatus.delivered);
      expect(entity.attemptCount, 1);
      expect(entity.createdAt, createdAt);
      expect(entity.lastAttemptAt, lastAttemptAt);
      expect(entity.payload['eventId'], 'e1');
      expect(entity.payload['title'], 'New application');
    });

    test('falls back to the document id when notificationId is absent', () {
      final doc = _MockDoc();
      when(() => doc.id).thenReturn('doc-id');
      final data = sampleData()..remove('notificationId');
      when(doc.data).thenReturn(data);

      final AppNotification entity =
          NotificationDto.fromFirestore(doc).toEntity();

      expect(entity.notificationId, 'doc-id');
    });

    test('handles a missing lastAttemptAt as null', () {
      final doc = _MockDoc();
      when(() => doc.id).thenReturn('n1');
      final data = sampleData()..remove('lastAttemptAt');
      when(doc.data).thenReturn(data);

      final AppNotification entity =
          NotificationDto.fromFirestore(doc).toEntity();

      expect(entity.lastAttemptAt, isNull);
    });

    test('toFirestore round-trips the entity wire representation', () {
      final entity = AppNotification(
        notificationId: 'n2',
        recipientId: 'student-9',
        type: NotificationType.applicationApproved,
        payload: const <String, Object?>{'title': 'Approved', 'body': 'Yay'},
        deliveryStatus: DeliveryStatus.pending,
        attemptCount: 0,
        createdAt: createdAt,
      );

      final Map<String, Object?> doc =
          NotificationDto.fromEntity(entity).toFirestore();

      expect(doc['notificationId'], 'n2');
      expect(doc['type'], 'ApplicationApproved');
      expect(doc['deliveryStatus'], 'Pending');
      expect(doc['attemptCount'], 0);
      expect(doc['createdAt'], Timestamp.fromDate(createdAt));
      expect(doc.containsKey('lastAttemptAt'), isFalse);
    });

    test('throws when the snapshot carries no data', () {
      final doc = _MockDoc();
      when(() => doc.id).thenReturn('n1');
      when(doc.data).thenReturn(null);

      expect(() => NotificationDto.fromFirestore(doc), throwsStateError);
    });
  });
}
