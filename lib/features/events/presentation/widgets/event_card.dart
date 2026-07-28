import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/event.dart';

/// A tappable card representing a single [Event] in a list.
///
/// Shared by the student dashboard's active-events list and the discovery
/// screen so both render events identically: a thumbnail tile, the title, the
/// date/time, the (net) pay-per-head, and a seats-left indicator. Pass [onTap]
/// to make it interactive (discovery); omit it for read-only lists (dashboard).
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
      decoration: AppDecorations.softCard(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Thumbnail tile (events have no image, so a branded slot).
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (applied) ...<Widget>[
                                const SizedBox(width: 8),
                                const _AppliedBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          _IconLine(
                            icon: Icons.calendar_today_outlined,
                            text: '${_date(event.date)} · '
                                '${_time(event.startTime)} - '
                                '${_time(event.endTime)}',
                          ),
                          const SizedBox(height: 3),
                          _IconLine(
                            icon: Icons.place_outlined,
                            text: event.location.label,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '₹${event.studentNetPayPerHead.formatted}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('/Day',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                    const Spacer(),
                    _SeatsLabel(event: event),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String _time(DateTime t) {
    final int h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final String m = t.minute.toString().padLeft(2, '0');
    final String ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

/// A muted icon + single-line text row (date/time, location) in a card.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// A small seats indicator: "N left" (or "Full" when no slots remain).
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
          full ? Icons.event_busy_outlined : Icons.handshake_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          full ? 'Full' : '$left left',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, size: 12, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'Applied',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
