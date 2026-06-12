import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';

/// A backend-neutral description of a profile photo to be uploaded.
///
/// Carries the raw image [bytes] together with its [contentType] (e.g.
/// `image/jpeg` or `image/png`) and a [fileName]. This is a pure domain value:
/// it references no backend storage type. Format/size acceptance (JPEG/PNG,
/// <= 5MB per R1.8) is enforced by the registration validator before the
/// upload is attempted.
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

/// Abstract gateway for storing and referencing profile photos.
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firebase Storage,
/// later S3/REST) lives in the data layer. No backend types ever cross this
/// boundary — methods speak pure domain values and `Result<T, Failure>`.
abstract class StorageRepository {
  /// Uploads [photo] for the user identified by [uid] and returns the stored
  /// reference (a backend-neutral storage path/key) on success (R1.9, R14.1).
  ///
  /// Returns a [Failure] (e.g. [PersistenceFailure]) when the upload fails.
  Future<Result<String, Failure>> uploadProfilePhoto({
    required String uid,
    required PhotoUpload photo,
  });

  /// Resolves a previously stored [reference] into a value the presentation
  /// layer can use to display the photo (e.g. a download URL).
  ///
  /// Returns a [Failure] (e.g. [NotFoundFailure]) when the reference cannot be
  /// resolved.
  Future<Result<String, Failure>> getPhotoUrl(String reference);
}
