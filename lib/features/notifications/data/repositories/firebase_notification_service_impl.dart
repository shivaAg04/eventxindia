import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/notification.dart';
import '../../domain/services/notification_service.dart';
import '../datasources/firebase_notification_data_source.dart';
import '../dtos/notification_dto.dart';

/// Firebase-backed implementation of the client/read surface of
/// [NotificationService] (R13.5, R13.7).
///
/// The trusted dispatch pipeline (FCM delivery with retry/skip/failure) runs
/// server-side behind this abstraction; this implementation only lets a
/// recipient observe their own notifications and manage the device token that
/// delivery targets. It never writes the delivery fields
/// ([AppNotification.deliveryStatus], [AppNotification.attemptCount]).
///
/// Reads stream from Firestore through the injected
/// [FirebaseNotificationDataSource] and are mapped to pure [AppNotification]
/// entities via [NotificationDto]. Token writes go through the data-layer
/// [withRetry] policy so a transient failure is retried and a total failure
/// surfaces a [PersistenceFailure] with no partial commit (R14.6).
@LazySingleton(as: NotificationService)
class FirebaseNotificationServiceImpl implements NotificationService {
  const FirebaseNotificationServiceImpl(this._dataSource);

  final FirebaseNotificationDataSource _dataSource;

  @override
  Stream<List<AppNotification>> watchForRecipient(String recipientId) {
    return _dataSource.streamForRecipient(recipientId).map(
          (docs) => docs
              .map((doc) => NotificationDto.fromFirestore(doc).toEntity())
              .toList(),
        );
  }

  @override
  Future<Result<Unit, Failure>> registerDeviceToken({
    required String userId,
    required String deviceToken,
  }) {
    return withRetry<Unit>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.addDeviceToken(userId, deviceToken);
        return unit;
      },
    );
  }

  @override
  Future<Result<Unit, Failure>> unregisterDeviceToken({
    required String userId,
    required String deviceToken,
  }) {
    return withRetry<Unit>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.removeDeviceToken(userId, deviceToken);
        return unit;
      },
    );
  }
}
