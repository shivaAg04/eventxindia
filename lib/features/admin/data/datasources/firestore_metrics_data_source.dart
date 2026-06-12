import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Firestore-backed read source for the `metrics/global` document (R6.7).
///
/// The admin counters are recomputed by the trusted `recomputeMetrics` Cloud
/// Function and written to the single `metrics/global` document; the client
/// only reads them. This wrapper exposes a one-shot read and a live stream of
/// that document, confining Firebase types to the data layer — the service
/// converts the emitted [DocumentSnapshot]s into the pure [Metrics] entity.
@injectable
class FirestoreMetricsDataSource extends FirestoreDataSource {
  /// Creates the data source over the injected [firestore] instance.
  const FirestoreMetricsDataSource(super.firestore);

  /// The name of the metrics collection in Firestore.
  static const String collectionPath = 'metrics';

  /// The id of the single aggregated-counters document.
  static const String globalDocId = 'global';

  DocumentReference<Map<String, dynamic>> get _doc =>
      firestore.collection(collectionPath).doc(globalDocId);

  /// Streams the `metrics/global` document, emitting a fresh snapshot whenever
  /// the trusted service recomputes the counters (R6.7).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGlobal() =>
      _doc.snapshots();

  /// Fetches the current `metrics/global` document once (R6.7).
  Future<DocumentSnapshot<Map<String, dynamic>>> getGlobal() => _doc.get();
}
