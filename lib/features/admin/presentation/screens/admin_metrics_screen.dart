import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/metrics.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';

/// Admin dashboard metrics screen (R6.7).
///
/// Renders the four aggregated platform counters — total students, total
/// vendors, active events, and completed events — each an integer of zero or
/// greater (R6.7). The counters are computed by the trusted aggregation service
/// and read here; before any aggregation has run the bloc emits [Metrics.zero].
/// A failed metrics stream surfaces as an [AdminActionFailure].
///
/// The screen owns its [AdminBloc], built from the injected [createBloc]
/// factory and started with [MetricsWatchStarted]; it never talks to a use case
/// or repository directly.
class AdminMetricsScreen extends StatelessWidget {
  const AdminMetricsScreen({required this.createBloc, super.key});

  /// Factory for the screen's [AdminBloc] (typically resolved from DI).
  final AdminBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminBloc>(
      create: (_) => createBloc()..add(const MetricsWatchStarted()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Dashboard metrics')),
        body: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            return switch (state) {
              MetricsLoaded(:final metrics) => _MetricsGrid(metrics: metrics),
              AdminActionFailure(:final message) =>
                _MetricsErrorView(message: message),
              _ => const Center(child: CircularProgressIndicator()),
            };
          },
        ),
      ),
    );
  }
}

/// The four-counter grid for a loaded [Metrics] projection (R6.7).
class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: <Widget>[
        _MetricCard(
          key: const ValueKey<String>('metric-total-students'),
          label: 'Total students',
          value: metrics.totalStudents,
        ),
        _MetricCard(
          key: const ValueKey<String>('metric-total-vendors'),
          label: 'Total vendors',
          value: metrics.totalVendors,
        ),
        _MetricCard(
          key: const ValueKey<String>('metric-active-events'),
          label: 'Active events',
          value: metrics.activeEvents,
        ),
        _MetricCard(
          key: const ValueKey<String>('metric-completed-events'),
          label: 'Completed events',
          value: metrics.completedEvents,
        ),
      ],
    );
  }
}

/// A single labelled counter card.
class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, super.key});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$value', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

/// Shown when the metrics stream errors.
class _MetricsErrorView extends StatelessWidget {
  const _MetricsErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Metrics could not be loaded.\n$message',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
