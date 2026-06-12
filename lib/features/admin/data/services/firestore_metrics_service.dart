import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/metrics.dart';
import '../../domain/services/metrics_service.dart';
import '../datasources/firestore_metrics_data_source.dart';

/// Client-side binding for the trusted [MetricsService] (R6.7).
///
/// Metric aggregation is a **trusted, server-side capability** — today the
/// `recomputeMetrics` Cloud Function writing `metrics/global` — so the client
/// never derives the counters; it only reads the document the backend
/// maintains. This implementation provides that read surface over
/// [FirestoreMetricsDataSource], mapping each `metrics/global` snapshot to the
/// pure [Metrics] entity.
///
/// Before any aggregation has run (a missing or empty document) it yields
/// [Metrics.zero], matching the contract. No backend type crosses this
/// boundary — the implementation speaks pure domain [Metrics] and
/// `Result<T, Failure>` only.
@LazySingleton(as: MetricsService)
class FirestoreMetricsService implements MetricsService {
  /// Creates the service over the injected [FirestoreMetricsDataSource].
  const FirestoreMetricsService(this._dataSource);

  final FirestoreMetricsDataSource _dataSource;

  @override
  Stream<Metrics> watchMetrics() {
    return _dataSource.watchGlobal().map(_toEntity);
  }

  @override
  Future<Result<Metrics, Failure>> getMetrics() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _dataSource.getGlobal();
      return Result<Metrics, Failure>.ok(_toEntity(snapshot));
    } catch (_) {
      return const Result<Metrics, Failure>.err(PersistenceFailure());
    }
  }

  /// Converts a `metrics/global` snapshot into a domain [Metrics], falling back
  /// to [Metrics.zero] when the document does not exist or a counter is absent
  /// (no aggregation has run yet).
  Metrics _toEntity(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return Metrics.zero;
    }
    return Metrics(
      totalStudents: _readCount(data['totalStudents']),
      totalVendors: _readCount(data['totalVendors']),
      activeEvents: _readCount(data['activeEvents']),
      completedEvents: _readCount(data['completedEvents']),
    );
  }

  /// Reads a non-negative counter from a raw Firestore value, treating a
  /// missing or negative value as zero so [Metrics] never sees a negative
  /// count.
  static int _readCount(Object? raw) {
    final int value = raw is num ? raw.toInt() : 0;
    return value < 0 ? 0 : value;
  }
}
