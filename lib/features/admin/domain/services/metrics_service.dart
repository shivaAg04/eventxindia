import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/metrics.dart';

/// Abstract service boundary for trusted admin-metric aggregation (R6.7).
///
/// Recomputing platform counters is a trusted, server-side capability rather
/// than a client computation: the counts must reflect authoritative
/// collection cardinalities regardless of the client. It is implemented today
/// by the Cloud Function `recomputeMetrics` writing `metrics/global`, and can
/// move to a Node.js aggregation job with no change to this interface.
///
/// The domain and presentation layers depend only on this abstraction; the
/// client reads the aggregated [Metrics] and never derives them itself.
abstract class MetricsService {
  /// Streams the latest aggregated [Metrics] for the Admin dashboard (R6.7).
  ///
  /// Emits a new [Metrics] each time the trusted service recomputes the
  /// counters. Before any aggregation has run, implementations emit
  /// [Metrics.zero].
  Stream<Metrics> watchMetrics();

  /// Reads the current aggregated [Metrics] once (R6.7).
  ///
  /// Returns the latest [Metrics] on success or a [Failure] when the read
  /// fails.
  Future<Result<Metrics, Failure>> getMetrics();
}
