import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/event.dart';

/// A glassy, tappable card representing a single [Event] in a list.
///
/// Shared by the student dashboard's active-events list and the discovery
/// screen so both render events identically: a gradient icon chip, the title
/// and location, and a "pay-per-head" pill. Pass [onTap] to make it
/// interactive (discovery); omit it for read-only lists (dashboard).
///
/// When [applied] is true an "Applied" badge is shown so a student can see, in
/// the list, that they have already applied to this event without opening it.
class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    this.onTap,
    this.applied = false,
    super.key,
  });

  final Event event;
  final VoidCallback? onTap;

  /// Whether the signed-in student has already applied to [event].
  final bool applied;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: AppDecorations.glassCard(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.event_rounded,
                    color: Color(0xFF0A0E1F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Flexible(child: _SeatsLabel(event: event)),
                          if (applied) ...<Widget>[
                            const SizedBox(width: 8),
                            const _AppliedBadge(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _PayPill(amount: event.studentNetPayPerHead.formatted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small seats indicator: "N seats left" (or "Full" when no slots remain).
class _SeatsLabel extends StatelessWidget {
  const _SeatsLabel({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final bool full = event.isFull;
    final Color color = full ? AppColors.danger : AppColors.textSecondary;
    final int left = event.seatsRemaining;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          full ? Icons.event_busy_outlined : Icons.event_seat_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            full
                ? 'Full'
                : '$left of ${event.slots} ${left == 1 ? 'seat' : 'seats'} left',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact "Applied" badge shown when the student has already applied to the
/// event, so the state is visible in the list (not only on the detail screen).
class _AppliedBadge extends StatelessWidget {
  const _AppliedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('event-card-applied-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, size: 12, color: AppColors.mint),
          SizedBox(width: 4),
          Text(
            'Applied',
            style: TextStyle(
              color: AppColors.mint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The mint-tinted "pay-per-head" pill shown on the trailing edge of a card.
class _PayPill extends StatelessWidget {
  const _PayPill({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
      ),
      child: Text(
        '₹$amount',
        style: const TextStyle(
          color: AppColors.mint,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
