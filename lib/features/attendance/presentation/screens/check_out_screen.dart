import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/attendance_bloc.dart';

/// Screen where a student enters the vendor's end code to check out of an event
/// (R10.6–R10.9).
///
/// Submitting dispatches [CheckOutRequested], which runs the [CheckOut] use
/// case. The UI reflects each state: a progress indicator while [CheckingOut],
/// a success confirmation with the computed working hours on [CheckedOut]
/// (R10.9), and the specific rejection reason on [AttendanceFailure] — an
/// invalid end code (R10.7) or a missing check-in (R10.8).
class CheckOutScreen extends StatefulWidget {
  const CheckOutScreen({
    required this.studentId,
    required this.eventId,
    super.key,
  });

  /// The id of the student checking out.
  final String studentId;

  /// The id of the event being checked out of.
  final String eventId;

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    context.read<AttendanceBloc>().add(
          CheckOutRequested(
            studentId: widget.studentId,
            eventId: widget.eventId,
            endCode: _codeController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check Out')),
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (BuildContext context, AttendanceState state) {
          final ScaffoldMessengerState messenger =
              ScaffoldMessenger.of(context);
          if (state is AttendanceFailure) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is CheckedOut) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Checked out successfully.')),
              );
          }
        },
        builder: (BuildContext context, AttendanceState state) {
          final bool busy = state is CheckingOut;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Enter the end code provided by the event organiser to '
                    'complete your shift.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'End code',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter the end code.'
                            : null,
                    onFieldSubmitted: (_) => busy ? null : _submit(context),
                  ),
                  const SizedBox(height: 16),
                  if (state is CheckingOut)
                    const _StatusLine(label: 'Checking you out...')
                  else if (state is CheckedOut)
                    _StatusLine(
                      label: state.record.workingHours == null
                          ? 'Checked out.'
                          : 'Checked out. '
                              'Working hours: ${state.record.workingHours}.',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    )
                  else if (state is AttendanceFailure)
                    _StatusLine(
                      label: state.message,
                      icon: Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : () => _submit(context),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Check out'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small status row with an optional [icon] and [color], used to surface the
/// in-flight, success, and failure states inline on the form.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
        ] else ...<Widget>[
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
