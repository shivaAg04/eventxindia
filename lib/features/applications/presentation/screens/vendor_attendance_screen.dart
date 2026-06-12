import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../bloc/application_bloc.dart';
import '../bloc/application_event.dart';
import '../bloc/application_state.dart';

/// Vendor-facing attendance management for a single owned event.
///
/// Combines attendance-code generation (R5.6) with the attendance view (R5.7):
/// - Two buttons dispatch [AttendanceCodeRequested] for the start/end codes;
///   the generated code is shown on success and an [ApplicationFailure] (e.g.
///   a non-owner request, R5.9) is surfaced as a snackbar.
/// - The attendance list is driven by [attendanceStream] (wired from
///   `AttendanceRepository.watchByEvent` at composition time), showing each
///   record's check-in/out times and working hours, or an empty-state
///   indication when none exist.
class VendorAttendanceScreen extends StatelessWidget {
  const VendorAttendanceScreen({
    required this.eventId,
    required this.vendorId,
    required this.attendanceStream,
    super.key,
  });

  /// The event whose codes/attendance are managed.
  final String eventId;

  /// The id of the vendor managing the event (resolved from the session).
  final String vendorId;

  /// Live stream of attendance records for the event (R5.7).
  final Stream<List<AttendanceRecord>> attendanceStream;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CodeGenerationPanel(eventId: eventId, vendorId: vendorId),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<AttendanceRecord>>(
              stream: attendanceStream,
              builder: (
                BuildContext context,
                AsyncSnapshot<List<AttendanceRecord>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to load attendance records.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<AttendanceRecord> records = snapshot.data!;
                if (records.isEmpty) {
                  return const Center(
                    child: Text('No attendance records for this event yet.'),
                  );
                }
                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) =>
                      _AttendanceTile(record: records[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The start/end code generation controls wired to [ApplicationBloc] (R5.6).
class _CodeGenerationPanel extends StatelessWidget {
  const _CodeGenerationPanel({required this.eventId, required this.vendorId});

  final String eventId;
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ApplicationBloc, ApplicationState>(
      listenWhen: (_, ApplicationState state) =>
          state is ApplicationFailure || state is AttendanceCodeGenerated,
      listener: (BuildContext context, ApplicationState state) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        if (state is ApplicationFailure) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.failure.message)));
        } else if (state is AttendanceCodeGenerated) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Code generated: ${state.code}')),
            );
        }
      },
      builder: (BuildContext context, ApplicationState state) {
        final String? code =
            state is AttendanceCodeGenerated ? state.code : null;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Start code'),
                      onPressed: () => _generate(context, EventCodeKind.start),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('End code'),
                      onPressed: () => _generate(context, EventCodeKind.end),
                    ),
                  ),
                ],
              ),
              if (code != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Latest code: $code',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _generate(BuildContext context, EventCodeKind kind) {
    context.read<ApplicationBloc>().add(
          AttendanceCodeRequested(
            vendorId: vendorId,
            eventId: eventId,
            kind: kind,
          ),
        );
  }
}

/// A single attendance record row (R5.7).
class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final String checkIn = record.checkInTime?.toString() ?? '—';
    final String checkOut = record.checkOutTime?.toString() ?? '—';
    final String hours = record.workingHours?.toStringAsFixed(2) ?? '—';
    return ListTile(
      title: Text(record.studentId),
      subtitle: Text('In: $checkIn\nOut: $checkOut'),
      isThreeLine: true,
      trailing: Text('$hours h'),
    );
  }
}
