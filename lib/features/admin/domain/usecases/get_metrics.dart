import '../entities/metrics.dart';
import '../services/metrics_service.dart';

/// Streams the latest aggregated admin dashboard [Metrics] (R6.7).
///
/// Delegates to [MetricsService.watchMetrics]: the counters are computed by
/// the trusted aggregation service and the client only reads them, so this use
/// case never derives the metrics itself. Before any aggregation has run the
/// service emits [Metrics.zero]. Depends only on the abstract
/// [MetricsService], so it carries no backend types.
class GetMetrics {
  const GetMetrics(this._service);

  final MetricsService _service;

  /// Returns the stream of aggregated [Metrics].
  Stream<Metrics> call() => _service.watchMetrics();
}
