import '../entities/application.dart';
import '../repositories/application_repository.dart';

/// Streams the applications submitted by a student (R4.2, R4.3).
///
/// This use case backs the student dashboard's "events I applied to" and
/// "events I was approved for" views: the caller filters the emitted list by
/// [Application.status] as needed. It delegates to
/// [ApplicationRepository.watchByStudent], emitting the current list of
/// [Application]s for [studentId] and a fresh list whenever it changes (an
/// empty list when the student has no applications).
///
/// This is pure domain logic: it depends only on the repository abstraction,
/// never on any backend type.
class WatchStudentApplications {
  /// Creates the use case with its injected [ApplicationRepository].
  const WatchStudentApplications({
    required ApplicationRepository applicationRepository,
  }) : _applicationRepository = applicationRepository;

  final ApplicationRepository _applicationRepository;

  /// Streams the applications submitted by the student identified by
  /// [studentId].
  Stream<List<Application>> call({required String studentId}) =>
      _applicationRepository.watchByStudent(studentId);
}
