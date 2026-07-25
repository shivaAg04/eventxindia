import 'package:flutter/material.dart';

import '../../../../core/value_objects/rating.dart';

/// A dialog that lets a vendor pick a 1..5 star rating for a student.
///
/// Owns its own selection state and pops the chosen [Rating] on confirm, or
/// `null` on cancel. Rating is one-time, so the caller only opens this for a
/// student who has not yet been rated for the event.
class RateStudentDialog extends StatefulWidget {
  const RateStudentDialog({required this.studentName, super.key});

  /// The name of the student being rated (shown in the title).
  final String studentName;

  /// Shows the dialog and returns the chosen [Rating], or `null` on cancel.
  static Future<Rating?> show(BuildContext context, String studentName) {
    return showDialog<Rating>(
      context: context,
      builder: (_) => RateStudentDialog(studentName: studentName),
    );
  }

  @override
  State<RateStudentDialog> createState() => _RateStudentDialogState();
}

class _RateStudentDialogState extends State<RateStudentDialog> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.studentName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Tap to rate — this cannot be changed later.'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 1; i <= Rating.maxStars; i++)
                IconButton(
                  key: ValueKey<String>('rate-star-$i'),
                  onPressed: () => setState(() => _selected = i),
                  icon: Icon(
                    i <= _selected ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected == 0
              ? null
              : () => Navigator.of(context).pop(Rating(_selected)),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
