import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../../../../core/value_objects/event_status.dart';

/// Firestore-backed data source for the `events` collection.
///
/// A thin wrapper over [FirebaseFirestore] that confines all Firestore query
/// and write calls for events to one place. It returns raw
/// [DocumentSnapshot]/[QuerySnapshot] payloads (or accepts Firestore-ready
/// maps); parsing to/from the pure domain [Event] is the DTO/repository's job,
/// keeping Firebase types inside the data layer (design "Backend independence"
/// rule).
@injectable
class FirestoreEventDataSource extends FirestoreDataSource {
  /// Creates a data source over the given [firestore] instance.
  const FirestoreEventDataSource(super.firestore);

  /// The name of the events collection (R7.6).
  static const String collectionName = 'events';

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(collectionName);

  /// Creates the event document identified by [eventId] from a Firestore-ready
  /// [data] map. A single document write, individually atomic.
  Future<void> create(String eventId, Map<String, dynamic> data) {
    return _collection.doc(eventId).set(data);
  }

  /// Fetches the event document identified by [eventId].
  Future<DocumentSnapshot<Map<String, dynamic>>> getById(String eventId) {
    return _collection.doc(eventId).get();
  }

  /// Streams every event whose `status` is [EventStatus.active] (R8.1),
  /// independent of remaining slots.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActive() {
    return _collection
        .where('status', isEqualTo: EventStatus.active.wireName)
        .snapshots();
  }

  /// Streams every event owned by the vendor identified by [vendorId] (R5.2).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchByVendor(String vendorId) {
    return _collection.where('vendorId', isEqualTo: vendorId).snapshots();
  }

  /// Merges [data] into the event document identified by [eventId].
  ///
  /// Used for status changes and attendance-code writes; a single document
  /// update, individually atomic.
  Future<void> update(String eventId, Map<String, dynamic> data) {
    return _collection.doc(eventId).update(data);
  }
}
