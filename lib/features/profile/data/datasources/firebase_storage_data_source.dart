import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Thin Firebase Storage data source for profile photos.
///
/// Confines Firebase Storage access for the profile feature to a single
/// injectable wrapper over [FirebaseStorage]: it uploads a photo to a
/// deterministic per-user path and resolves a stored reference into a download
/// URL (R1.9). The repository implementation owns failure mapping and any
/// retry policy.
@injectable
class FirebaseStorageDataSource extends FirebaseStorageDataSourceBase {
  FirebaseStorageDataSource(super.storage);

  static const String _profilePhotosPath = 'profile_photos';

  /// The Storage object path used for a user's profile photo.
  String photoPath(String uid) => '$_profilePhotosPath/$uid';

  /// Uploads [bytes] to `profile_photos/{uid}` with [contentType] and returns
  /// the stored object path (the backend-neutral reference).
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final String path = photoPath(uid);
    final Reference ref = storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  /// Resolves a stored object [reference] into a download URL.
  Future<String> getDownloadUrl(String reference) =>
      storage.ref(reference).getDownloadURL();
}
