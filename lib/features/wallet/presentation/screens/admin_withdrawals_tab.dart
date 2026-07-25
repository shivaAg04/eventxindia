import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/usecases/decide_withdrawal.dart';
import '../bloc/withdrawal_review_cubit.dart';

/// Admin tab listing every wallet withdrawal request, newest first, with
/// approve / reject actions for pending ones (R11 wallet).
///
/// Owns its [WithdrawalReviewCubit] from the injected [createCubit] factory and
/// starts it with [WithdrawalReviewCubit.watch]; a decision is dispatched
/// through the cubit and its outcome surfaced as a snackbar, while the list
/// updates itself from the stream.
class AdminWithdrawalsTab extends StatelessWidget {
  const AdminWithdrawalsTab({
    required this.createCubit,
    required this.studentNames,
    required this.onOpenStudent,
    super.key,
  });

  final WithdrawalReviewCubit Function() createCubit;

  /// Maps a student id to their display name, resolved by the caller from the
  /// loaded admin lists; the id is shown when a name is missing.
  final Map<String, String> studentNames;

  /// Opens the student-detail page when a request row is tapped.
  final void Function(BuildContext context, String studentId) onOpenStudent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WithdrawalReviewCubit>(
      create: (_) => createCubit()..watch(),
      child: BlocBuilder<WithdrawalReviewCubit, WithdrawalReviewState>(
        builder: (BuildContext context, WithdrawalReviewState state) {
          return switch (state) {
            WithdrawalReviewLoading() =>
              const Center(child: CircularProgressIndicator()),
            WithdrawalReviewFailure() => const _Empty(
                message: 'Withdrawal requests could not be loaded.',
              ),
            WithdrawalReviewLoaded(:final List<WithdrawalRequest> requests) =>
              requests.isEmpty
                  ? const _Empty(message: 'No withdrawal requests yet.')
                  : ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) =>
                          _WithdrawalTile(
                        request: requests[index],
                        studentNames: studentNames,
                        onOpenStudent: onOpenStudent,
                      ),
                    ),
          };
        },
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({
    required this.request,
    required this.studentNames,
    required this.onOpenStudent,
  });

  final WithdrawalRequest request;
  final Map<String, String> studentNames;
  final void Function(BuildContext context, String studentId) onOpenStudent;

  Future<void> _decide(
    BuildContext context,
    WithdrawalDecision decision,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Result<Unit, Failure> result =
        await context.read<WithdrawalReviewCubit>().decide(request.id, decision);
    if (result.isErr) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(result.failureOrNull!.message)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String studentName =
        studentNames[request.studentId] ?? request.studentId;
    return ListTile(
      key: ValueKey<String>('withdrawal-${request.id}'),
      leading: const Icon(Icons.account_balance_wallet_outlined),
      onTap: () => onOpenStudent(context, request.studentId),
      title: Text(studentName, style: theme.textTheme.titleMedium),
      subtitle: Text('₹${request.amount.formatted}'),
      isThreeLine: true,
      trailing: request.isPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: ValueKey<String>('withdrawal-approve-${request.id}'),
                  tooltip: 'Approve',
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () =>
                      _decide(context, WithdrawalDecision.approve),
                ),
                IconButton(
                  key: ValueKey<String>('withdrawal-reject-${request.id}'),
                  tooltip: 'Reject',
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () => _decide(context, WithdrawalDecision.reject),
                ),
              ],
            )
          : _StatusChip(status: request.status),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final WithdrawalStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status.wireName));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inbox_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
