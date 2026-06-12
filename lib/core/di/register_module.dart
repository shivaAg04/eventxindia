import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

/// Supplies the external Firebase singletons the data layer depends on but
/// cannot annotate itself (they live in third-party packages).
///
/// This is part of the composition root: the data sources take their Firebase
/// SDK handles (`FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`,
/// `FirebaseMessaging`) by constructor, and `injectable` resolves them from
/// the bindings declared here. Swapping the backend means replacing this module
/// (and the repository/service bindings) — nothing in domain or presentation
/// changes.
@module
abstract class RegisterModule {
  /// The app-wide Firebase Authentication handle.
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  /// The app-wide Cloud Firestore handle.
  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  /// The app-wide Firebase Cloud Storage handle.
  @lazySingleton
  FirebaseStorage get firebaseStorage => FirebaseStorage.instance;

  /// The app-wide Firebase Cloud Messaging handle.
  @lazySingleton
  FirebaseMessaging get firebaseMessaging => FirebaseMessaging.instance;
}
