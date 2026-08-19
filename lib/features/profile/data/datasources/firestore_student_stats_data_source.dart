import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Firestore-backed read source for the `studentStats/{studentId}` documents
/// (R5.3, R5.4).
///
/// A student's track-record counters are recomputed by the trusted
/// `recomputeStudentStats*` Cloud Functions; the client only reads them. This
/// wrapper exposes a one-shot read and a live stream of one student's document,
/// confining Firebase types to the data layer — the service converts the
/// emitted [DocumentSnapshot]s into the pure `StudentStats` entity.
@injectable
class FirestoreStudentStatsDataSource extends FirestoreDataSource {
  /// Creates the data source over the injected [firestore] instance.
  const FirestoreStudentStatsDataSource(super.firestore);

  /// The name of the student-stats collection in Firestore.
  static const String collectionPath = 'studentStats';

  DocumentReference<Map<String, dynamic>> _doc(String studentId) =>
      firestore.collection(collectionPath).doc(studentId);

  /// Streams one student's counters document, emitting a fresh snapshot
  /// whenever the trusted service recomputes it.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchByStudent(
    String studentId,
  ) =>
      _doc(studentId).snapshots();

  /// Fetches one student's counters document once.
  Future<DocumentSnapshot<Map<String, dynamic>>> getByStudent(
    String studentId,
  ) =>
      _doc(studentId).get();
}
