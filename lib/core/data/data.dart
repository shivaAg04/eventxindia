/// Shared data-layer infrastructure (Firebase backend).
///
/// Re-exports the Firebase initialization entrypoint, the thin data-source base
/// wrappers over the Firebase SDKs, and the pure write-retry policy (R14.1,
/// R14.6) that feature data sources and repository implementations build on.
library;

export 'firebase_data_source.dart';
export 'firebase_initializer.dart';
export 'write_retry.dart';
