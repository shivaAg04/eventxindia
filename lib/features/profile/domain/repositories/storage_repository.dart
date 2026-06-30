import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';

/// A backend-neutral profile photo to upload: raw [bytes], [contentType]
/// (e.g. `image/jpeg`), and [fileName]. Format/size (JPEG/PNG, <= 5MB, R1.8)
/// is checked by the validator before upload.
class PhotoUpload {
  const PhotoUpload({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  /// The raw image bytes.
  final Uint8List bytes;

  /// The MIME content type, e.g. `image/jpeg` or `image/png`.
  final String contentType;

  /// The original file name of the photo.
  final String fileName;

  /// The size of the photo in bytes.
  int get sizeBytes => bytes.length;
}

/// Gateway for storing and referencing profile photos — the backend swap line.
/// Implemented by the data layer (today Firebase Storage); no backend type
/// crosses it.
abstract class StorageRepository {
  /// Uploads [photo] for [uid] and returns the stored reference (a
  /// backend-neutral path/key), or a [Failure] on error (R1.9, R14.1).
  Future<Result<String, Failure>> uploadProfilePhoto({
    required String uid,
    required PhotoUpload photo,
  });

  /// Resolves a stored [reference] into a displayable URL, or [NotFoundFailure].
  Future<Result<String, Failure>> getPhotoUrl(String reference);
}
