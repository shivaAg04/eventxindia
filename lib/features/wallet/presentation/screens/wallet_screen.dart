import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dashboard_header.dart';
import '../../../../core/value_objects/money.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../bloc/wallet_cubit.dart';

/// The student's wallet (R11 wallet).
///
/// Shows the total balance and its breakdown (pending / withdrawable / paid
/// out), lets the student request a withdrawal (validated against the available
/// balance), and lists the per-event credits and withdrawal requests as a
/// transaction history. This is bookkeeping only — no real payout gateway.
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
        body: Column(
          children: <Widget>[
            const DashboardHeader(
              title: 'Wallet',
              subtitle: 'Track your earnings ✨',
            ),
            Expanded(
              child: BlocBuilder<WalletCubit, WalletState>(
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
          ],
        ),
      ),
    );
  }
}

class _WalletView extends StatelessWidget {
  const _WalletView({required this.wallet, required this.getEvent});

  final Wallet wallet;
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

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

    final Money? amount = await showDialog<Money>(
      context: context,
      builder: (_) => _RequestWithdrawalDialog(available: wallet.available),
    );
    if (amount == null) {
      return;
    }

    final Result<WithdrawalRequest, Failure> result =
        await cubit.request(amount);
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
    final bool noTxns = credits.isEmpty && wallet.withdrawals.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _BalanceCard(wallet: wallet),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            _StatTile(
              label: 'Pending',
              value: wallet.pendingTotal,
              icon: Icons.schedule_rounded,
              accent: AppColors.amber,
            ),
            const SizedBox(width: 10),
            _StatTile(
              label: 'Withdrawable',
              value: wallet.available,
              valueColor: AppColors.success,
              icon: Icons.account_balance_wallet_outlined,
              accent: AppColors.success,
            ),
            const SizedBox(width: 10),
            _StatTile(
              label: 'Payout',
              value: wallet.approvedTotal,
              icon: Icons.north_east_rounded,
              accent: AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Withdraw action styled as a card row (mockup).
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          shadowColor: const Color(0x14101828),
          child: InkWell(
            key: const ValueKey<String>('wallet-request-withdrawal'),
            borderRadius: BorderRadius.circular(16),
            onTap: canRequest ? () => _openRequestDialog(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: <Widget>[
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_rupee_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Withdraw',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: canRequest
                          ? AppColors.primary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: canRequest
                          ? AppColors.primary
                          : AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            canRequest
                ? 'Withdraw your available balance to your bank.'
                : 'Complete an event to earn a withdrawable balance.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Recent Transactions',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (noTxns)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  height: 72,
                  width: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('👛', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 12),
                Text('No transactions yet.',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Your transactions will appear here.',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          )
        else ...<Widget>[
          // Money out — withdrawal requests (carry a date).
          for (final WithdrawalRequest w in wallet.withdrawals)
            _TxnRow(
              icon: Icons.north_east,
              iconColor: AppColors.danger,
              title: 'Withdrawal to bank',
              subtitle: 'Requested ${_formatDate(w.createdAt)}',
              amount: '-₹${w.amount.formatted}',
              amountColor: AppColors.danger,
              trailing: _WithdrawalStatusBadge(status: w.status),
            ),
          // Money in — per-event credits (net of platform commission).
          for (final MapEntry<String, Money> c in credits)
            _TxnRow(
              key: ValueKey<String>('wallet-credit-${c.key}'),
              icon: Icons.south_west,
              iconColor: AppColors.success,
              title: wallet.eventNames[c.key] ?? c.key,
              subtitle: 'Event earning',
              amount: '+₹${c.value.formatted}',
              amountColor: AppColors.success,
              trailing: const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
              onTap: () => _openEvent(context, c.key),
            ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime d) {
    final DateTime local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

/// The headline balance card — a brand-red hero with the total balance.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.brandHero(),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Total Balance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${wallet.credited.formatted}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

/// A small white stat tile (Pending / Withdrawable / Paid out).
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.valueColor,
  });

  final String label;
  final Money value;
  final IconData icon;
  final Color accent;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                '₹${value.formatted}',
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single transaction row: a tinted icon chip, title/subtitle, and a coloured
/// signed amount (with an optional trailing badge/chevron).
class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  amount,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(height: 4),
                  trailing!,
                ],
              ],
            ),
          ],
        ),
      ),
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

class _WithdrawalStatusBadge extends StatelessWidget {
  const _WithdrawalStatusBadge({required this.status});

  final WithdrawalStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      WithdrawalStatus.approved => AppColors.success,
      WithdrawalStatus.rejected => AppColors.danger,
      WithdrawalStatus.pending => AppColors.amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.wireName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
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
