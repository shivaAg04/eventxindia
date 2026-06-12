import '../entities/event.dart';
import '../repositories/event_repository.dart';

/// Streams the [Event]s owned by a vendor for the vendor's "Manage Events" view
/// (R5.2).
///
/// The stream re-emits whenever the vendor's event set changes; an empty list
/// signals that the vendor has created no events, which the presentation layer
/// renders as an empty-list indication (R5.2).
class WatchVendorEvents {
  const WatchVendorEvents({required EventRepository repository})
      : _repository = repository;

  final EventRepository _repository;

  /// Returns the stream of events owned by the vendor identified by [vendorId].
  Stream<List<Event>> call(String vendorId) =>
      _repository.watchByVendor(vendorId);
}
