import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/money.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../bloc/wallet_cubit.dart';

/// The student's wallet (R11 wallet).
///
/// Shows the available balance and its breakdown (credited / on hold / paid
/// out), lets the student request a withdrawal (validated against the available
/// balance), and lists both the withdrawal requests and the per-event credits
/// as a transaction history. This is bookkeeping only — no real payout gateway.
class WalletScreen extends StatelessWidget {
  const WalletScreen({
    required this.studentId,
    required this.createCubit,
    required this.getEvent,
    super.key,
  });

  final String studentId;
  final WalletCubit Function() createCubit;

  /// Fetches a single event by id, so a tapped event credit can open the
  /// event-detail screen. Backed by the `GetEvent` use case.
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WalletCubit>(
      create: (_) => createCubit()..watch(studentId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: BlocBuilder<WalletCubit, WalletState>(
          builder: (BuildContext context, WalletState state) {
            return switch (state) {
              WalletLoading() =>
                const Center(child: CircularProgressIndicator()),
              WalletFailure(:final String message) => _Message(
                  icon: Icons.error_outline,
                  text: 'Your wallet could not be loaded.\n$message',
                ),
              WalletLoaded(:final Wallet wallet) =>
                _WalletView(wallet: wallet, getEvent: getEvent),
            };
          },
        ),
      ),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView({required this.wallet, required this.getEvent});

  final Wallet wallet;
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

  /// Fetches the event for [eventId] and opens its read-only detail screen, or
  /// surfaces the failure as a snackbar.
  Future<void> _openEvent(BuildContext context, String eventId) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Result<Event, Failure> result = await getEvent(eventId);
    result.fold<void>(
      (Event event) => navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      (Failure f) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _openRequestDialog(BuildContext context) async {
    final WalletCubit cubit = context.read<WalletCubit>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // The dialog owns its own controller/state (a dedicated StatefulWidget), so
    // it is disposed cleanly with the dialog and returns the chosen amount.
    final Money? amount = await showDialog<Money>(
      context: context,
      builder: (_) => _RequestWithdrawalDialog(available: wallet.available),
    );
    if (amount == null) {
      return;
    }

    final Result<WithdrawalRequest, Failure> result = await cubit.request(amount);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.fold<String>(
              (WithdrawalRequest _) =>
                  'Withdrawal requested — pending admin review.',
              (Failure f) => f.message,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<MapEntry<String, Money>> credits =
        wallet.creditsPerEvent.entries.toList(growable: false);
    final bool canRequest = wallet.available.minorUnits > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _BalanceCard(wallet: wallet),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey<String>('wallet-request-withdrawal'),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Request withdrawal'),
          onPressed: canRequest ? () => _openRequestDialog(context) : null,
        ),
        if (!canRequest)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Complete an event to earn a withdrawable balance.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 24),
        Text('Withdrawal requests', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (wallet.withdrawals.isEmpty)
          Text('No withdrawal requests yet.',
              style: theme.textTheme.bodySmall)
        else
          for (final WithdrawalRequest w in wallet.withdrawals)
            _WithdrawalTile(request: w),
        const SizedBox(height: 24),
        Text('Event credits', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (credits.isEmpty)
          Text('No event credits yet.', style: theme.textTheme.bodySmall)
        else
          for (final MapEntry<String, Money> c in credits)
            ListTile(
              key: ValueKey<String>('wallet-credit-${c.key}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.south_west, color: Colors.greenAccent),
              title: Text(wallet.eventNames[c.key] ?? c.key),
              onTap: () => _openEvent(context, c.key),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '+₹${c.value.formatted}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
      ],
    );
  }
}

/// The "request withdrawal" dialog. Owns its own [TextEditingController] and
/// validates the amount against [available]; pops the chosen [Money] (or `null`
/// on cancel).
class _RequestWithdrawalDialog extends StatefulWidget {
  const _RequestWithdrawalDialog({required this.available});

  final Money available;

  @override
  State<_RequestWithdrawalDialog> createState() =>
      _RequestWithdrawalDialogState();
}

class _RequestWithdrawalDialogState extends State<_RequestWithdrawalDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Money? _parseAmount(String raw) {
    try {
      return Money.parse(raw.trim(), requirePayPerHeadRange: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  void _submit() {
    final Money? amount = _parseAmount(_controller.text);
    if (amount == null || amount.minorUnits <= 0) {
      setState(() => _errorText = 'Enter a valid amount.');
      return;
    }
    if (amount.minorUnits > widget.available.minorUnits) {
      setState(() => _errorText = 'More than your available balance.');
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request withdrawal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Available: ₹${widget.available.formatted}'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Request'),
        ),
      ],
    );
  }
}

/// The headline balance card: available amount + credited / on-hold / paid-out.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Available balance', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              '₹${wallet.available.formatted}',
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Divider(height: 28),
            Row(
              children: <Widget>[
                _Stat(label: 'Earned', value: wallet.credited),
                _Stat(label: 'On hold', value: wallet.pendingTotal),
                _Stat(label: 'Paid out', value: wallet.approvedTotal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final Money value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            '₹${value.formatted}',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A single withdrawal-request row: amount, date, and status badge.
class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.request});

  final WithdrawalRequest request;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      key: ValueKey<String>('wallet-withdrawal-${request.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.north_east),
      title: Text('-₹${request.amount.formatted}',
          style: theme.textTheme.titleMedium),
      subtitle: Text('Requested ${_formatDate(request.createdAt)}'),
      trailing: _WithdrawalStatusBadge(status: request.status),
    );
  }

  static String _formatDate(DateTime d) {
    final DateTime local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

class _WithdrawalStatusBadge extends StatelessWidget {
  const _WithdrawalStatusBadge({required this.status});

  final WithdrawalStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      WithdrawalStatus.approved => Colors.greenAccent,
      WithdrawalStatus.rejected => Theme.of(context).colorScheme.error,
      WithdrawalStatus.pending => Colors.amberAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.wireName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
