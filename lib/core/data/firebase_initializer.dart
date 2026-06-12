import 'package:firebase_core/firebase_core.dart';

/// Initializes the Firebase backend for the data layer (R14.1).
///
/// This is the single entrypoint the composition root / `main` calls during
/// bootstrap (wired in task 31.2). It is deliberately defensive:
///
/// - It is idempotent. If a `[DEFAULT]` Firebase app already exists (for
///   example because initialization ran earlier in the app's lifecycle, or in a
///   test harness), the existing app is returned instead of throwing a
///   duplicate-app error.
/// - It does **not** hard-depend on a generated `firebase_options.dart`. That
///   file is produced by `flutterfire configure` and is intentionally absent
///   here (it would carry project secrets). Callers that have generated options
///   can pass them via [options]; otherwise the platform's native
///   configuration (google-services.json / GoogleService-Info.plist) is used.
///
/// Pass [options] (e.g. `DefaultFirebaseOptions.currentPlatform`) once a
/// `firebase_options.dart` has been generated for the project.
Future<FirebaseApp> initializeFirebase({FirebaseOptions? options}) async {
  // Reuse an already-initialized default app to keep this idempotent.
  if (Firebase.apps.isNotEmpty) {
    return Firebase.app();
  }
  return Firebase.initializeApp(options: options);
}
