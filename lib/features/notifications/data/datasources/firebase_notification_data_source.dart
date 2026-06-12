import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Data source backing the client/read surface of the notification capability
/// (R13.5, R13.7).
///
/// Notifications are read from Cloud Firestore (the `notifications` collection,
/// written by the trusted backend), while device tokens are registered against
/// the user document and obtained from Firebase Cloud Messaging. This wrapper
/// therefore depends on both [FirebaseFirestore] (via [FirestoreDataSource])
/// and [FirebaseMessaging] (via [FirebaseMessagingDataSourceBase]); it confines
/// those Firebase types to the data layer.
///
/// It exposes:
/// - a recipient-filtered, most-recent-first stream over `notifications`
///   (R13.5),
/// - idempotent add/remove of an FCM token on `users/{uid}.deviceTokens`
///   (R13.7),
/// - a passthrough to obtain the device's current FCM token from the SDK.
@injectable
class FirebaseNotificationDataSource extends FirestoreDataSource
    implements FirebaseMessagingDataSourceBase {
  const FirebaseNotificationDataSource(
    super.firestore, {
    required this.messaging,
  });

  @override
  final FirebaseMessaging messaging;

  static const String _notificationsCollection = 'notifications';
  static const String _usersCollection = 'users';

  /// Streams the notifications addressed to [recipientId], most recent first
  /// (R13.5). Recipients read only their own notifications.
  Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>> streamForRecipient(
    String recipientId,
  ) {
    return firestore
        .collection(_notificationsCollection)
        .where('recipientId', isEqualTo: recipientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Adds [deviceToken] to `users/{userId}.deviceTokens` (R13.7).
  ///
  /// Uses [FieldValue.arrayUnion] with a merging set so repeated registrations
  /// of the same token are idempotent and the user document is not clobbered.
  Future<void> addDeviceToken(String userId, String deviceToken) {
    return firestore.collection(_usersCollection).doc(userId).set(
      <String, Object?>{
        'deviceTokens': FieldValue.arrayUnion(<String>[deviceToken]),
      },
      SetOptions(merge: true),
    );
  }

  /// Removes [deviceToken] from `users/{userId}.deviceTokens`, e.g. on sign-out.
  Future<void> removeDeviceToken(String userId, String deviceToken) {
    return firestore.collection(_usersCollection).doc(userId).set(
      <String, Object?>{
        'deviceTokens': FieldValue.arrayRemove(<String>[deviceToken]),
      },
      SetOptions(merge: true),
    );
  }

  /// Returns the device's current FCM registration token from the SDK, or
  /// `null` when none is available.
  Future<String?> currentDeviceToken() => messaging.getToken();
}
