import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/storage_repository.dart';
import '../datasources/firebase_storage_data_source.dart';

/// Firebase Storage-backed implementation of [StorageRepository].
///
/// Uploads profile photos to `profile_photos/{uid}` and returns the stored
/// object path as the backend-neutral reference; resolves a stored reference
/// into a download URL for display (R1.9). The upload goes through the pure
/// [withRetry] policy (`maxAttempts = 3`) so a failed upload is retried and
/// nothing partial is committed on total failure (R14.6).
@LazySingleton(as: StorageRepository)
class FirebaseStorageRepositoryImpl implements StorageRepository {
  const FirebaseStorageRepositoryImpl(this._dataSource);

  final FirebaseStorageDataSource _dataSource;

  @override
  Future<Result<String, Failure>> uploadProfilePhoto({
    required String uid,
    required PhotoUpload photo,
  }) {
    return withRetry<String>(
      kDefaultMaxWriteAttempts,
      () => _dataSource.uploadProfilePhoto(
        uid: uid,
        bytes: photo.bytes,
        contentType: photo.contentType,
      ),
    );
  }

  @override
  Future<Result<String, Failure>> getPhotoUrl(String reference) async {
    try {
      final String url = await _dataSource.getDownloadUrl(reference);
      return Result<String, Failure>.ok(url);
    } catch (_) {
      return const Result<String, Failure>.err(NotFoundFailure());
    }
  }
}
