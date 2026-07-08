import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../../domain/entities/application.dart';
import '../bloc/application_bloc.dart';
import '../bloc/application_event.dart';
import '../bloc/application_state.dart';

/// Vendor-facing attendance management for a single owned event.
///
/// Combines attendance-code generation (R5.6) with the attendance view (R5.7):
/// - Two buttons dispatch [AttendanceCodeRequested] for the start/end codes;
///   the generated code is shown on success and an [ApplicationFailure] (e.g.
///   a non-owner request, R5.9) is surfaced as a snackbar.
/// - Below, a **Check-in** and a **Check-out** tab each list every enrolled
///   (approved) student for the event, joining [enrolledStream] (approved
///   applications) with [attendanceStream] (their attendance records) so the
///   vendor can see, per student, whether they have checked in / out and when.
///   A filter narrows each tab to All / Done / Pending.
class VendorAttendanceScreen extends StatelessWidget {
  const VendorAttendanceScreen({
    required this.eventId,
    required this.vendorId,
    required this.attendanceStream,
    required this.enrolledStream,
    super.key,
  });

  /// The event whose codes/attendance are managed.
  final String eventId;

  /// The id of the vendor managing the event (resolved from the session).
  final String vendorId;

  /// Live stream of attendance records for the event (R5.7).
  final Stream<List<AttendanceRecord>> attendanceStream;

  /// Live stream of the event's applications; the approved ones are the
  /// enrolled students shown in both tabs (R5.3, R5.7).
  final Stream<List<Application>> enrolledStream;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CodeGenerationPanel(eventId: eventId, vendorId: vendorId),
            const Divider(height: 1),
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Check-in'),
                Tab(text: 'Check-out'),
              ],
            ),
            Expanded(
              child: _EnrolledRoster(
                attendanceStream: attendanceStream,
                enrolledStream: enrolledStream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Joins the enrolled (approved) students with their attendance records and
/// renders the two tab views. The [TabBar] lives above this in
/// [VendorAttendanceScreen] so switching tabs is unaffected by stream updates.
class _EnrolledRoster extends StatelessWidget {
  const _EnrolledRoster({
    required this.attendanceStream,
    required this.enrolledStream,
  });

  final Stream<List<AttendanceRecord>> attendanceStream;
  final Stream<List<Application>> enrolledStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Application>>(
      stream: enrolledStream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<Application>> appsSnapshot,
      ) {
        if (appsSnapshot.hasError) {
          return const Center(child: Text('Failed to load enrolled students.'));
        }
        if (!appsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<Application> enrolled = appsSnapshot.data!
            .where((Application a) => a.status == ApplicationStatus.approved)
            .toList(growable: false);

        return StreamBuilder<List<AttendanceRecord>>(
          stream: attendanceStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<AttendanceRecord>> attSnapshot,
          ) {
            final List<AttendanceRecord> records =
                attSnapshot.data ?? const <AttendanceRecord>[];
            final Map<String, AttendanceRecord> byStudent =
                <String, AttendanceRecord>{
              for (final AttendanceRecord r in records) r.studentId: r,
            };
            final List<_RosterEntry> entries = enrolled
                .map((Application a) =>
                    _RosterEntry(application: a, record: byStudent[a.studentId]))
                .toList(growable: false);

            return TabBarView(
              children: <Widget>[
                _RosterTab(entries: entries, mode: _AttendanceMode.checkIn),
                _RosterTab(entries: entries, mode: _AttendanceMode.checkOut),
              ],
            );
          },
        );
      },
    );
  }
}

/// Which attendance action a roster tab reports on.
enum _AttendanceMode { checkIn, checkOut }

/// The status filter applied within a roster tab.
enum _RosterFilter { all, done, pending }

/// An enrolled student paired with their attendance record (if any).
class _RosterEntry {
  const _RosterEntry({required this.application, this.record});

  final Application application;
  final AttendanceRecord? record;

  /// Whether the student has completed this tab's action (checked in / out).
  bool isDone(_AttendanceMode mode) => switch (mode) {
        _AttendanceMode.checkIn => record?.checkInTime != null,
        _AttendanceMode.checkOut => record?.checkOutTime != null,
      };

  /// The timestamp of this tab's action, if recorded.
  DateTime? timeFor(_AttendanceMode mode) => switch (mode) {
        _AttendanceMode.checkIn => record?.checkInTime,
        _AttendanceMode.checkOut => record?.checkOutTime,
      };
}

/// One tab's list of enrolled students, with an All / Done / Pending filter over
/// the tab's action (check-in or check-out).
class _RosterTab extends StatefulWidget {
  const _RosterTab({required this.entries, required this.mode});

  final List<_RosterEntry> entries;
  final _AttendanceMode mode;

  @override
  State<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends State<_RosterTab>
    with AutomaticKeepAliveClientMixin {
  _RosterFilter _filter = _RosterFilter.all;

  @override
  bool get wantKeepAlive => true;

  String get _doneLabel =>
      widget.mode == _AttendanceMode.checkIn ? 'Checked in' : 'Checked out';

  String get _pendingLabel => widget.mode == _AttendanceMode.checkIn
      ? 'Not checked in'
      : 'Not checked out';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.entries.isEmpty) {
      return const Center(child: Text('No students enrolled yet.'));
    }
    final List<_RosterEntry> visible = widget.entries.where((_RosterEntry e) {
      final bool done = e.isDone(widget.mode);
      return switch (_filter) {
        _RosterFilter.all => true,
        _RosterFilter.done => done,
        _RosterFilter.pending => !done,
      };
    }).toList(growable: false);

    final int doneCount =
        widget.entries.where((_RosterEntry e) => e.isDone(widget.mode)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: <Widget>[
              for (final (_RosterFilter value, String label) in <(
                _RosterFilter,
                String
              )>[
                (_RosterFilter.all, 'All (${widget.entries.length})'),
                (_RosterFilter.done, '$_doneLabel ($doneCount)'),
                (
                  _RosterFilter.pending,
                  'Pending (${widget.entries.length - doneCount})'
                ),
              ]) ...<Widget>[
                ChoiceChip(
                  key: ValueKey<String>(
                    'roster-filter-${widget.mode.name}-${value.name}',
                  ),
                  label: Text(label),
                  selected: _filter == value,
                  onSelected: (_) => setState(() => _filter = value),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No students match this filter.'))
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) =>
                      _RosterTile(
                    entry: visible[index],
                    mode: widget.mode,
                    doneLabel: _doneLabel,
                    pendingLabel: _pendingLabel,
                  ),
                ),
        ),
      ],
    );
  }
}

/// A single enrolled-student row for a roster tab.
class _RosterTile extends StatelessWidget {
  const _RosterTile({
    required this.entry,
    required this.mode,
    required this.doneLabel,
    required this.pendingLabel,
  });

  final _RosterEntry entry;
  final _AttendanceMode mode;
  final String doneLabel;
  final String pendingLabel;

  @override
  Widget build(BuildContext context) {
    final Application app = entry.application;
    final bool done = entry.isDone(mode);
    final DateTime? time = entry.timeFor(mode);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color color = done ? Colors.greenAccent : colors.onSurfaceVariant;

    return ListTile(
      key: ValueKey<String>('roster-${mode.name}-${app.studentId}'),
      leading: const Icon(Icons.person_outline),
      title: Text(app.applicantName ?? app.studentId),
      subtitle: Text(
        done && time != null ? '$doneLabel: ${_formatTime(time)}' : pendingLabel,
      ),
      trailing: Icon(
        done ? Icons.check_circle : Icons.schedule_outlined,
        color: color,
      ),
    );
  }

  /// Formats [t] as `YYYY-MM-DD HH:MM` without depending on locale data.
  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

/// The start/end code generation controls wired to [ApplicationBloc] (R5.6).
///
/// Each button generates and persists its code independently; the generated
/// check-in and check-out codes are then shown side by side in their own
/// labelled slots and retained across generations, so the vendor can always see
/// and share the correct code for each action (and, crucially, knows to
/// generate the check-out code before students try to check out).
class _CodeGenerationPanel extends StatefulWidget {
  const _CodeGenerationPanel({required this.eventId, required this.vendorId});

  final String eventId;
  final String vendorId;

  @override
  State<_CodeGenerationPanel> createState() => _CodeGenerationPanelState();
}

class _CodeGenerationPanelState extends State<_CodeGenerationPanel> {
  String? _startCode;
  String? _endCode;

  void _generate(EventCodeKind kind) {
    context.read<ApplicationBloc>().add(
          AttendanceCodeRequested(
            vendorId: widget.vendorId,
            eventId: widget.eventId,
            kind: kind,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ApplicationBloc, ApplicationState>(
      listenWhen: (_, ApplicationState state) =>
          state is ApplicationFailure || state is AttendanceCodeGenerated,
      listener: (BuildContext context, ApplicationState state) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        if (state is ApplicationFailure) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.failure.message)));
        } else if (state is AttendanceCodeGenerated) {
          setState(() {
            if (state.kind == EventCodeKind.start) {
              _startCode = state.code;
            } else {
              _endCode = state.code;
            }
          });
          final String label =
              state.kind == EventCodeKind.start ? 'Check-in' : 'Check-out';
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('$label code generated: ${state.code}')),
            );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Check-in'),
                    onPressed: () => _generate(EventCodeKind.start),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Check-out'),
                    onPressed: () => _generate(EventCodeKind.end),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // IntrinsicHeight bounds the Row's height so the two slots can
            // stretch to an equal height without inheriting the Column's
            // unbounded main-axis constraint (which would force infinite
            // height on a cross-axis-stretch Row).
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _CodeSlot(label: 'Check-in code', code: _startCode),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CodeSlot(label: 'Check-out code', code: _endCode),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled slot showing a generated attendance [code] (or a placeholder when
/// it has not been generated yet), so both codes stay visible for sharing.
class _CodeSlot extends StatelessWidget {
  const _CodeSlot({required this.label, required this.code});

  final String label;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool has = code != null;
    return Container(
      key: ValueKey<String>('code-slot-$label'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: has ? theme.colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(12),
        border: has ? null : Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              code ?? 'Not generated',
              maxLines: 1,
              style: has
                  ? theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    )
                  : theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

