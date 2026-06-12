/// Barrel file exporting the core, backend-neutral value objects.
///
/// These pure value objects enforce validity at construction and are shared
/// across the domain layer. No backend (Firebase) type appears here.
library;

export 'application_status.dart';
export 'approval_status.dart';
export 'event_status.dart';
export 'geo_point.dart';
export 'money.dart';
export 'phone_number.dart';
