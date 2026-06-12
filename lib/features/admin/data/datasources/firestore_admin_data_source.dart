import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Firestore data source backing [FirestoreAdminRepositoryImpl].
///
/// A thin wrapper over [FirebaseFirestore] that confines all Firebase query
/// types to the data layer. It exposes:
/// - read streams over the admin monitoring collections (`students`,
///   `vendors`, `events`, `reports`) for the Admin lists (R6.4–R6.6, R6.8),
/// - a single-document read of a vendor used by the approval/reject flow,
/// - guarded writes for the vendor approval transition and the per-user
///   device-token registration (R6.1–R6.3, R13.7, R14.5).
///
/// Each accessor returns raw [DocumentSnapshot]s / [QuerySnapshot]s; conversion
/// to domain entities happens in the repository via the inline mappers.
@injectable
class FirestoreAdminDataSource extends FirestoreDataSource {
  const FirestoreAdminDataSource(super.firestore);

  static const String _studentsCollection = 'students';
  static const String _vendorsCollection = 'vendors';
  static const String _eventsCollection = 'events';
  static const String _reportsCollection = 'reports';
  static const String _usersCollection = 'users';

  /// Streams all `students` documents for the Admin student list (R6.4).
  Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>> streamStudents() {
    return firestore
        .collection(_studentsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Streams all `vendors` documents for the Admin vendor list (R6.5).
  Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>> streamVendors() {
    return firestore
        .collection(_vendorsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Streams all `events` documents for the Admin event list (R6.6).
  Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>> streamEvents() {
    return firestore
        .collection(_eventsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Streams all `reports` documents for the Admin reports view (R6.8).
  Stream<List<QueryDocumentSnapshot<Map<String, Object?>>>> streamReports() {
    return firestore
        .collection(_reportsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Reads the `vendors/{vendorId}` document once (used by approve/reject).
  Future<DocumentSnapshot<Map<String, Object?>>> getVendor(String vendorId) {
    return firestore.collection(_vendorsCollection).doc(vendorId).get();
  }

  /// Sets the vendor's `approvalStatus` and `updatedAt` fields (R6.1–R6.3).
  ///
  /// This is an admin/trusted write; the Pending-only guard is enforced by the
  /// use case before this is called.
  Future<void> setVendorApprovalStatus(
    String vendorId,
    String approvalStatus,
    DateTime updatedAt,
  ) {
    return firestore.collection(_vendorsCollection).doc(vendorId).update(
      <String, Object?>{
        'approvalStatus': approvalStatus,
        'updatedAt': Timestamp.fromDate(updatedAt),
      },
    );
  }

  /// Adds [token] to `users/{uid}.deviceTokens`, creating the array if needed
  /// (R13.7, R14.5). Uses [FieldValue.arrayUnion] so repeated registrations of
  /// the same token are idempotent.
  Future<void> addDeviceToken(String uid, String token) {
    return firestore.collection(_usersCollection).doc(uid).set(
      <String, Object?>{
        'deviceTokens': FieldValue.arrayUnion(<String>[token]),
      },
      SetOptions(merge: true),
    );
  }
}
