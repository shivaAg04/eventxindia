import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Base for data sources backed by Cloud Firestore.
///
/// Holds a single [FirebaseFirestore] instance and exposes a typed accessor so
/// feature data sources (e.g. `FirestoreEventDataSource`) only depend on this
/// thin wrapper rather than reaching for `FirebaseFirestore.instance` directly.
/// This keeps Firebase types confined to the data layer (design "Backend
/// independence" rule) and makes the instance injectable for tests.
abstract class FirestoreDataSource {
  const FirestoreDataSource(this.firestore);

  /// The Firestore instance this data source reads from / writes to.
  final FirebaseFirestore firestore;
}

/// Base for data sources backed by Firebase Authentication.
///
/// Wraps a single [FirebaseAuth] instance for auth data sources
/// (e.g. `FirebaseAuthDataSource`).
abstract class FirebaseAuthDataSourceBase {
  const FirebaseAuthDataSourceBase(this.auth);

  /// The Firebase Auth instance backing this data source.
  final FirebaseAuth auth;
}

/// Base for data sources backed by Firebase Cloud Storage.
///
/// Wraps a single [FirebaseStorage] instance for storage data sources
/// (e.g. profile-photo uploads).
abstract class FirebaseStorageDataSourceBase {
  const FirebaseStorageDataSourceBase(this.storage);

  /// The Firebase Storage instance backing this data source.
  final FirebaseStorage storage;
}

/// Base for data sources backed by Firebase Cloud Messaging.
///
/// Wraps a single [FirebaseMessaging] instance for messaging data sources
/// (e.g. device-token registration).
abstract class FirebaseMessagingDataSourceBase {
  const FirebaseMessagingDataSourceBase(this.messaging);

  /// The Firebase Messaging instance backing this data source.
  final FirebaseMessaging messaging;
}
