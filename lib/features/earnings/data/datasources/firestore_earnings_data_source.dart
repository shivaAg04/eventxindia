import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Firestore-backed read source for the `earnings/{studentId}` collection.
///
/// Exposes only reads: a one-shot fetch and a live stream of a student's
/// earnings document. The client never writes earnings — accrual is performed
/// exactly once by the trusted [EarningsService] backend (R11.1, R11.2) — so
/// this data source has no write methods (R11.3, R11.4, R14.4).
///
/// Firebase types stay confined here and in the DTO; the repository converts
/// the emitted [DocumentSnapshot]s into pure domain entities.
@injectable
class FirestoreEarningsDataSource extends FirestoreDataSource {
  /// Creates the data source over the injected [firestore] instance.
  const FirestoreEarningsDataSource(super.firestore);

  /// The name of the earnings collection in Firestore.
  static const String collectionPath = 'earnings';

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(collectionPath);

  /// Streams the `earnings/{studentId}` document, emitting a fresh snapshot
  /// whenever it changes.
  ///
  /// The snapshot may be non-existent when the student has no earnings yet; the
  /// repository maps that to an empty projection (R11.5).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchByStudent(
    String studentId,
  ) =>
      _collection.doc(studentId).snapshots();

  /// Fetches the current `earnings/{studentId}` document once.
  ///
  /// The returned snapshot may be non-existent when the student has no earnings
  /// yet; the repository maps that to an empty projection (R11.5).
  Future<DocumentSnapshot<Map<String, dynamic>>> getByStudent(
    String studentId,
  ) =>
      _collection.doc(studentId).get();
}
