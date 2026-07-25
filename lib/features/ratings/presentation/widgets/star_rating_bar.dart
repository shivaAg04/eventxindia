import 'package:flutter/material.dart';

import '../../../../core/value_objects/rating.dart';

/// A compact, read-only row of five stars showing a given [stars] score.
///
/// Used wherever a rating is displayed (student profile average, per-event
/// rating on cards, admin views). For a fractional [stars] (e.g. an average of
/// 4.3) a half star is shown for the fractional part.
class StarRatingBar extends StatelessWidget {
  const StarRatingBar({
    required this.stars,
    this.size = 16,
    this.color = Colors.amber,
    super.key,
  });

  /// The score to display, `1.0 .. 5.0` (may be fractional for an average).
  final double stars;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= Rating.maxStars; i++)
          Icon(
            stars >= i
                ? Icons.star
                : (stars >= i - 0.5 ? Icons.star_half : Icons.star_border),
            size: size,
            color: color,
          ),
      ],
    );
  }
}

/// A star score followed by its numeric value, e.g. ★★★★☆ 4.0. Pass a
/// [count] to append the number of ratings (e.g. "· 12").
class StarRatingLabel extends StatelessWidget {
  const StarRatingLabel({
    required this.stars,
    this.size = 16,
    this.count,
    super.key,
  });

  final double stars;
  final double size;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        StarRatingBar(stars: stars, size: size),
        const SizedBox(width: 6),
        Text(
          count == null
              ? stars.toStringAsFixed(1)
              : '${stars.toStringAsFixed(1)} · $count',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
