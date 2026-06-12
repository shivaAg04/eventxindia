import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/application.dart';

/// Abstract gateway for persisting and observing [Application] records.
///
/// This is the domain-owned swap line: use cases depend only on this
/// interface, and a backend-specific implementation (today Firestore, later a
/// REST/WebSocket backend) lives in the data layer. No backend types ever
/// cross this boundary — every method speaks pure domain [Application] values
/// and `Result<T, Failure>`.
///
/// Each application is stored under the composite id
/// `"{eventId}_{studentId}"` (R9.6), which the [create] implementation must
/// honour so that a duplicate application for the same event is rejected
/// (R9.2) rather than silently overwriting the existing record.
abstract class ApplicationRepository {
  /// Persists a newly created [application].
  ///
  /// Implementations must create the record only when no application with the
  /// same composite id already exists, leaving any existing record unchanged
  /// (R9.1, R9.2, R9.6).
  Future<Result<Application, Failure>> create(Application application);

  /// Persists the decided [application], typically after its status has
  /// transitioned to approved or rejected by the owning vendor (R9.3, R9.4).
  Future<Result<Application, Failure>> decide(Application application);

  /// Returns the application identified by [applicationId], or a failure when
  /// no such application exists.
  Future<Result<Application, Failure>> getById(String applicationId);

  /// Streams the applications submitted to the event identified by [eventId].
  Stream<List<Application>> watchByEvent(String eventId);

  /// Streams the applications submitted by the student identified by
  /// [studentId].
  Stream<List<Application>> watchByStudent(String studentId);
}
