import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/money.dart';
import '../bloc/earnings_bloc.dart';
import '../bloc/earnings_event.dart';
import '../bloc/earnings_state.dart';

/// Read-only screen showing a student's estimated earnings.
///
/// Renders the monetary [Money] total (R11.3) and the amount credited for each
/// completed event (R11.4). When the student has no completed attendance
/// records it shows a zero total and an empty per-event list (R11.5). Earnings
/// are estimates only — there is no wallet, withdrawal, or payment action here
/// (R11.6).
///
/// The screen owns its [EarningsBloc], created from the injected [bloc] factory
/// and started for [studentId]; it never talks to a use case or repository
/// directly.
class EarningsScreen extends StatelessWidget {
  /// Creates the earnings screen for [studentId], using [createBloc] to build
  /// and start the [EarningsBloc].
  const EarningsScreen({
    required this.studentId,
    required this.createBloc,
    super.key,
  });

  /// The id of the student whose earnings are displayed.
  final String studentId;

  /// Factory for the screen's [EarningsBloc] (typically resolved from DI).
  final EarningsBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EarningsBloc>(
      create: (_) => createBloc()..add(EarningsWatchStarted(studentId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Earnings')),
        body: BlocBuilder<EarningsBloc, EarningsState>(
          builder: (context, state) {
            return switch (state) {
              EarningsLoading() =>
                const Center(child: CircularProgressIndicator()),
              EarningsEmpty() => const _EarningsEmptyView(),
              EarningsLoaded(:final total, :final perEvent) =>
                _EarningsLoadedView(total: total, perEvent: perEvent),
              EarningsFailure(:final message) =>
                _EarningsErrorView(message: message),
            };
          },
        ),
      ),
    );
  }
}

/// Formats a [Money] amount as a rupee monetary string, e.g. `₹123.45`.
String _formatMoney(Money money) => '₹${money.formatted}';

/// Total card plus the per-event credit list for a populated projection.
class _EarningsLoadedView extends StatelessWidget {
  const _EarningsLoadedView({required this.total, required this.perEvent});

  final Money total;
  final Map<String, Money> perEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = perEvent.entries.toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _TotalCard(total: total),
        const SizedBox(height: 24),
        Text('Per-event earnings', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in entries)
          ListTile(
            key: ValueKey<String>(entry.key),
            title: Text(entry.key),
            trailing: Text(
              _formatMoney(entry.value),
              style: theme.textTheme.titleMedium,
            ),
          ),
      ],
    );
  }
}

/// Empty projection: zero total and no per-event credits (R11.5).
class _EarningsEmptyView extends StatelessWidget {
  const _EarningsEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _TotalCard(total: Money.zero),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'No completed events yet',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// The estimated earnings total, displayed as a monetary amount (R11.3).
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});

  final Money total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Estimated earnings', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              _formatMoney(total),
              style: theme.textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the earnings stream errors (R4.7).
class _EarningsErrorView extends StatelessWidget {
  const _EarningsErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Earnings could not be loaded.\n$message',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
