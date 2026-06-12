import '../entities/application.dart';
import '../repositories/application_repository.dart';

/// Streams the applications submitted to one of a vendor's events (R5.3, R5.9).
///
/// This use case backs the vendor's applicant-list view for a single event.
/// It delegates to [ApplicationRepository.watchByEvent], emitting the current
/// list of [Application]s for [eventId] and a fresh list whenever it changes
/// (an empty list when no applications exist).
///
/// Per-event ownership (R5.9) is enforced where the decision is made — see
/// [DecideApplication] — and at the data/security layer; this read-only stream
/// surfaces the applications for the event the vendor has navigated to.
///
/// This is pure domain logic: it depends only on the repository abstraction,
/// never on any backend type.
class WatchEventApplications {
  /// Creates the use case with its injected [ApplicationRepository].
  const WatchEventApplications({
    required ApplicationRepository applicationRepository,
  }) : _applicationRepository = applicationRepository;

  final ApplicationRepository _applicationRepository;

  /// Streams the applications submitted to the event identified by [eventId].
  Stream<List<Application>> call({required String eventId}) =>
      _applicationRepository.watchByEvent(eventId);
}
