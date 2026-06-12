import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/attendance_record.dart';
import '../bloc/attendance_bloc.dart';

/// Screen that lists a student's attendance history (R4.4).
///
/// On first build it dispatches [HistoryWatchStarted] to subscribe to the
/// student's attendance stream and renders [HistoryLoaded] as a list of
/// records, with an empty-state message when the student has no attendance yet
/// and a progress indicator until the first emission.
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({required this.studentId, super.key});

  /// The id of the student whose attendance history is shown.
  final String studentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: BlocBuilder<AttendanceBloc, AttendanceState>(
        builder: (BuildContext context, AttendanceState state) {
          if (state is! HistoryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.records.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have no attendance records yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: state.records.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) =>
                _AttendanceTile(record: state.records[index]),
          );
        },
      ),
    );
  }
}

/// A single attendance record row showing the event, check-in/out times, and
/// the computed working hours when the record is completed.
class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final String subtitle = record.isCompleted
        ? 'In: ${_format(record.checkInTime)}  •  '
            'Out: ${_format(record.checkOutTime)}'
        : record.isCheckedIn
            ? 'Checked in: ${_format(record.checkInTime)}'
            : 'Not checked in';

    return ListTile(
      leading: Icon(
        record.isCompleted
            ? Icons.task_alt
            : record.isCheckedIn
                ? Icons.login
                : Icons.schedule,
      ),
      title: Text('Event ${record.eventId}'),
      subtitle: Text(subtitle),
      trailing: record.workingHours == null
          ? null
          : Text(
              '${record.workingHours} h',
              style: Theme.of(context).textTheme.labelLarge,
            ),
    );
  }

  /// Formats a [time] as `YYYY-MM-DD HH:MM`, or an em dash when absent.
  static String _format(DateTime? time) {
    if (time == null) {
      return '—';
    }
    final DateTime local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
