import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/storage_repository.dart';

/// Firebase Storage-backed implementation of [StorageRepository].
///
/// Uploads profile photos to `profile_photos/{uid}` and returns the stored
/// object path as the backend-neutral reference; resolves a stored reference
/// into a download URL for display (R1.9). The upload goes through the pure
/// [withRetry] policy (`maxAttempts = 3`) so a failed upload is retried and
/// nothing partial is committed on total failure (R14.6).
///
/// Firebase Storage access is confined to this class; no Firebase type crosses
/// back to the use-case layer.
@LazySingleton(as: StorageRepository)
class FirebaseStorageRepositoryImpl implements StorageRepository {
  const FirebaseStorageRepositoryImpl(this._storage);

  final FirebaseStorage _storage;

  static const String _profilePhotosPath = 'profile_photos';

  @override
  Future<Result<String, Failure>> uploadProfilePhoto({
    required String uid,
    required PhotoUpload photo,
  }) {
    final String path = '$_profilePhotosPath/$uid';
    return withRetry<String>(kDefaultMaxWriteAttempts, () async {
      await _storage.ref(path).putData(
            photo.bytes,
            SettableMetadata(contentType: photo.contentType),
          );
      return path;
    });
  }

  @override
  Future<Result<String, Failure>> getPhotoUrl(String reference) async {
    try {
      final String url = await _storage.ref(reference).getDownloadURL();
      return Result<String, Failure>.ok(url);
    } catch (_) {
      return const Result<String, Failure>.err(NotFoundFailure());
    }
  }
}
