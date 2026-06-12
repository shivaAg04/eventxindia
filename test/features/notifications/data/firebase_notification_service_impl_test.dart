import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventxindia/features/notifications/data/datasources/firebase_notification_data_source.dart';
import 'package:eventxindia/features/notifications/data/repositories/firebase_notification_service_impl.dart';
import 'package:eventxindia/features/notifications/domain/entities/delivery_status.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification.dart';
import 'package:eventxindia/features/notifications/domain/entities/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, Object?>> {}

/// A hand-written fake over the data source so we exercise the service's
/// mapping and retry behaviour without a live Firestore.
class _FakeDataSource implements FirebaseNotificationDataSource {
  _FakeDataSource({
    this.recipientStream = const Stream.empty(),
    this.addShouldThrow = false,
    this.removeShouldThrow = false,
  });

  final Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>>
      recipientStream;
  final bool addShouldThrow;
  final bool removeShouldThrow;

  int addCalls = 0;
  int removeCalls = 0;
  String? lastUserId;
  String? lastToken;

  @override
  Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>> streamForRecipient(
    String recipientId,
  ) {
    return recipientStream;
  }

  @override
  Future<void> addDeviceToken(String userId, String deviceToken) async {
    addCalls++;
    lastUserId = userId;
    lastToken = deviceToken;
    if (addShouldThrow) {
      throw Exception('write failed');
    }
  }

  @override
  Future<void> removeDeviceToken(String userId, String deviceToken) async {
    removeCalls++;
    lastUserId = userId;
    lastToken = deviceToken;
    if (removeShouldThrow) {
      throw Exception('write failed');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  QueryDocumentSnapshot<Map<String, Object?>> doc(
    String id,
    Map<String, Object?> data,
  ) {
    final d = _MockQueryDoc();
    when(() => d.id).thenReturn(id);
    when(d.data).thenReturn(data);
    return d;
  }

  group('FirebaseNotificationServiceImpl', () {
    test('watchForRecipient maps documents to domain entities', () async {
      final stream = Stream<
          List<QueryDocumentSnapshot<Map<String, Object?>>>>.value(
        <QueryDocumentSnapshot<Map<String, Object?>>>[
          doc('n1', <String, Object?>{
            'notificationId': 'n1',
            'recipientId': 'r1',
            'type': 'EventReminder',
            'payload': <String, Object?>{'title': 't', 'body': 'b'},
            'deliveryStatus': 'Pending',
            'attemptCount': 0,
            'createdAt': Timestamp.fromDate(DateTime(2025, 3, 1)),
          }),
        ],
      );
      final service =
          FirebaseNotificationServiceImpl(_FakeDataSource(recipientStream: stream));

      final List<AppNotification> first =
          await service.watchForRecipient('r1').first;

      expect(first, hasLength(1));
      expect(first.single.type, NotificationType.eventReminder);
      expect(first.single.deliveryStatus, DeliveryStatus.pending);
    });

    test('registerDeviceToken writes the token and returns Ok', () async {
      final ds = _FakeDataSource();
      final service = FirebaseNotificationServiceImpl(ds);

      final result = await service.registerDeviceToken(
        userId: 'u1',
        deviceToken: 'tok-1',
      );

      expect(result.isOk, isTrue);
      expect(ds.addCalls, 1);
      expect(ds.lastUserId, 'u1');
      expect(ds.lastToken, 'tok-1');
    });

    test('registerDeviceToken returns a failure after retries are exhausted',
        () async {
      final ds = _FakeDataSource(addShouldThrow: true);
      final service = FirebaseNotificationServiceImpl(ds);

      final result = await service.registerDeviceToken(
        userId: 'u1',
        deviceToken: 'tok-1',
      );

      expect(result.isErr, isTrue);
      expect(ds.addCalls, 3);
    });

    test('unregisterDeviceToken removes the token and returns Ok', () async {
      final ds = _FakeDataSource();
      final service = FirebaseNotificationServiceImpl(ds);

      final result = await service.unregisterDeviceToken(
        userId: 'u1',
        deviceToken: 'tok-1',
      );

      expect(result.isOk, isTrue);
      expect(ds.removeCalls, 1);
    });
  });
}
