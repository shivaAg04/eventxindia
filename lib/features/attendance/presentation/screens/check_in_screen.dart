import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/attendance_bloc.dart';

/// Screen where a student enters the vendor's start code to check in to an
/// event (R10.1–R10.5).
///
/// Submitting dispatches [CheckInRequested]; the bloc acquires the device
/// location (R10.4) and runs the [CheckIn] use case. The UI reflects each
/// state: a progress indicator while [LocatingDevice]/[CheckingIn], a success
/// confirmation on [CheckedIn], and the specific rejection reason on
/// [AttendanceFailure] (R10.2, R10.3, R10.5).
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    required this.studentId,
    required this.eventId,
    super.key,
  });

  /// The id of the student checking in.
  final String studentId;

  /// The id of the event being checked in to.
  final String eventId;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
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
          CheckInRequested(
            studentId: widget.studentId,
            eventId: widget.eventId,
            startCode: _codeController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check In')),
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (BuildContext context, AttendanceState state) {
          final ScaffoldMessengerState messenger =
              ScaffoldMessenger.of(context);
          if (state is AttendanceFailure) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is CheckedIn) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Checked in successfully.')),
              );
          }
        },
        builder: (BuildContext context, AttendanceState state) {
          final bool busy = state is LocatingDevice || state is CheckingIn;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Enter the start code provided by the event organiser. '
                    'Your location will be verified.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    enabled: !busy,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Start code',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter the start code.'
                            : null,
                    onFieldSubmitted: (_) => busy ? null : _submit(context),
                  ),
                  const SizedBox(height: 16),
                  if (state is LocatingDevice)
                    const _StatusLine(label: 'Locating your device...')
                  else if (state is CheckingIn)
                    const _StatusLine(label: 'Checking you in...')
                  else if (state is CheckedIn)
                    const _StatusLine(
                      label: 'Checked in.',
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
                        : const Text('Check in'),
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
