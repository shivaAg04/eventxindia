import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
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
        appBar: AppBar(
          title: const Text('Dashboard metrics'),
          actions: const <Widget>[LogoutButton()],
        ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        Text(
          'Platform overview',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.15,
          children: <Widget>[
            _MetricCard(
              key: const ValueKey<String>('metric-total-students'),
              label: 'Total students',
              value: metrics.totalStudents,
              icon: Icons.people_alt_rounded,
              accent: AppColors.primary,
            ),
            _MetricCard(
              key: const ValueKey<String>('metric-total-vendors'),
              label: 'Total vendors',
              value: metrics.totalVendors,
              icon: Icons.storefront_rounded,
              accent: AppColors.violet,
            ),
            _MetricCard(
              key: const ValueKey<String>('metric-active-events'),
              label: 'Active events',
              value: metrics.activeEvents,
              icon: Icons.bolt_rounded,
              accent: AppColors.mint,
            ),
            _MetricCard(
              key: const ValueKey<String>('metric-completed-events'),
              label: 'Completed events',
              value: metrics.completedEvents,
              icon: Icons.check_circle_rounded,
              accent: AppColors.amber,
            ),
          ],
        ),
      ],
    );
  }
}

/// A single labelled counter card: an accent icon chip, a large value, and the
/// counter's label.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const Spacer(),
          Text(
            '$value',
            style: text.displaySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
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
