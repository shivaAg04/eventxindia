import 'dart:typed_data';

import '../../domain/repositories/storage_repository.dart';

/// A backend/platform-neutral abstraction for choosing a profile photo.
///
/// The registration screen depends only on this interface so it never has to
/// know whether the bytes come from the device gallery, the camera, or a test
/// double. A platform implementation (e.g. one backed by `image_picker`) can be
/// injected later without touching the screen; until then [StubPhotoPicker]
/// supplies a small, valid placeholder so the photo-picker flow is fully wired
/// end to end.
abstract class ProfilePhotoPicker {
  /// Prompts the user to choose a photo, returning the selected image as a
  /// [PhotoUpload], or `null` when the user cancels.
  Future<PhotoUpload?> pickPhoto();
}

/// A no-dependency [ProfilePhotoPicker] that returns a tiny, valid PNG.
///
/// This lets the registration screen exercise the full photo-picker → BLoC
/// flow (and pass the JPEG/PNG + size validation of R1.8) without pulling in a
/// platform image-picker dependency. Swap it for a real implementation when one
/// is available.
class StubPhotoPicker implements ProfilePhotoPicker {
  const StubPhotoPicker();

  @override
  Future<PhotoUpload?> pickPhoto() async {
    return PhotoUpload(
      bytes: Uint8List.fromList(_transparentPngBytes),
      contentType: 'image/png',
      fileName: 'profile_photo.png',
    );
  }

  /// The bytes of a 1×1 transparent PNG — a minimal, structurally valid image.
  static const List<int> _transparentPngBytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
    0x42, 0x60, 0x82, //
  ];
}
