import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/event_status_policy.dart';
import '../../../config/presentation/bloc/platform_config_cubit.dart';
import '../../../config/presentation/screens/admin_settings_screen.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../../../wallet/presentation/bloc/withdrawal_review_cubit.dart';
import '../../../wallet/presentation/screens/admin_withdrawals_tab.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_revenue_cubit.dart';
import '../bloc/admin_state.dart';
import 'admin_event_detail_screen.dart';
import 'admin_revenue_screen.dart';
import 'admin_student_detail_screen.dart';
import 'admin_vendor_detail_screen.dart';

/// Admin monitoring screen showing the student, vendor, and event lists, with
/// vendor approval/rejection actions (R6.1–R6.6, R6.9).
///
/// Tabs render the registered students (R6.4), the vendors each with their
/// approval status and approve/reject controls for pending vendors (R6.1,
/// R6.2, R6.5), and the events each with their lifecycle status (R6.6). When
/// every list is empty the bloc emits [EmptyState] and the screen shows an
/// empty-state indication (R6.9). A failed approve/reject surfaces as a
/// [AdminActionFailure] snackbar conveying that the vendor is not Pending
/// (R6.3).
///
/// The screen owns its [AdminBloc], built from the injected [createBloc]
/// factory and started with [ListsWatchStarted]; it never talks to a use case
/// or repository directly.
/// Sets an event's admin moderation status (approve/reject) and reports whether
/// the write succeeded, so the admin lists can show a confirmation. Publishing
/// an event to students is exactly moving it to [ApprovalStatus.approved].
typedef SetEventApprovalFn = Future<bool> Function(
  String eventId,
  ApprovalStatus status,
);

class AdminListsScreen extends StatelessWidget {
  const AdminListsScreen({
    required this.createBloc,
    required this.createAdminRevenueCubit,
    required this.createWithdrawalReviewCubit,
    required this.createWalletCubit,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.watchVendorEvents,
    required this.watchStudentApplications,
    required this.watchStudentAttendance,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.createPlatformConfigCubit,
    required this.setEventApproval,
    super.key,
  });

  /// Approves or rejects an event's publish gate (R6 admin moderation).
  final SetEventApprovalFn setEventApproval;

  /// Factory for the screen's [AdminBloc] (typically resolved from DI).
  final AdminBloc Function() createBloc;

  /// Factory for the Revenue tab's [AdminRevenueCubit].
  final AdminRevenueCubit Function() createAdminRevenueCubit;

  /// Factory for the Withdrawals tab's [WithdrawalReviewCubit].
  final WithdrawalReviewCubit Function() createWithdrawalReviewCubit;

  /// Factory for the [WalletCubit] used on the student drill-down.
  final WalletCubit Function() createWalletCubit;

  /// Streams backing the admin drill-down detail screens (R6).
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;
  final Stream<List<Application>> Function(String studentId)
      watchStudentApplications;
  final Stream<List<AttendanceRecord>> Function(String studentId)
      watchStudentAttendance;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

  /// Factory for the platform-settings [PlatformConfigCubit].
  final PlatformConfigCubit Function() createPlatformConfigCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminBloc>(
      create: (_) => createBloc()..add(const ListsWatchStarted()),
      child: _AdminListsView(
        createAdminRevenueCubit: createAdminRevenueCubit,
        createWithdrawalReviewCubit: createWithdrawalReviewCubit,
        createWalletCubit: createWalletCubit,
        watchEventAttendance: watchEventAttendance,
        watchEventApplications: watchEventApplications,
        watchVendorEvents: watchVendorEvents,
        watchStudentApplications: watchStudentApplications,
        watchStudentAttendance: watchStudentAttendance,
        watchEventRatings: watchEventRatings,
        watchStudentRatings: watchStudentRatings,
        createPlatformConfigCubit: createPlatformConfigCubit,
        setEventApproval: setEventApproval,
      ),
    );
  }
}

class _AdminListsView extends StatelessWidget {
  const _AdminListsView({
    required this.createAdminRevenueCubit,
    required this.createWithdrawalReviewCubit,
    required this.createWalletCubit,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.watchVendorEvents,
    required this.watchStudentApplications,
    required this.watchStudentAttendance,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.createPlatformConfigCubit,
    required this.setEventApproval,
  });

  final SetEventApprovalFn setEventApproval;
  final AdminRevenueCubit Function() createAdminRevenueCubit;
  final WithdrawalReviewCubit Function() createWithdrawalReviewCubit;
  final WalletCubit Function() createWalletCubit;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;
  final Stream<List<Application>> Function(String studentId)
      watchStudentApplications;
  final Stream<List<AttendanceRecord>> Function(String studentId)
      watchStudentAttendance;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final PlatformConfigCubit Function() createPlatformConfigCubit;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('admin-open-settings'),
              tooltip: 'Platform settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AdminSettingsScreen(
                    createCubit: createPlatformConfigCubit,
                  ),
                ),
              ),
            ),
            const LogoutButton(),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Students'),
              Tab(text: 'Vendors'),
              Tab(text: 'Events'),
              Tab(text: 'Withdrawals'),
              Tab(text: 'Revenue'),
            ],
          ),
        ),
        body: BlocConsumer<AdminBloc, AdminState>(
          listenWhen: (_, state) => state is AdminActionFailure,
          listener: (context, state) {
            if (state is AdminActionFailure) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          buildWhen: (_, state) =>
              state is ListsLoaded ||
              state is EmptyState ||
              state is AdminInitial,
          builder: (context, state) {
            final bool loading = state is! ListsLoaded && state is! EmptyState;
            final List<Student> students =
                state is ListsLoaded ? state.students : const <Student>[];
            final List<Vendor> vendors =
                state is ListsLoaded ? state.vendors : const <Vendor>[];
            final List<Event> events =
                state is ListsLoaded ? state.events : const <Event>[];

            // Cross-linked navigation: an event's participant opens the student
            // detail, an event opens its vendor's detail, and a student's/
            // vendor's event opens the event detail. All resolve the full entity
            // from the already-loaded admin lists.
            late final void Function(BuildContext, String) openEvent;
            late final void Function(BuildContext, String) openStudent;
            late final void Function(BuildContext, String) openVendor;

            // Id → display name for resolving a withdrawal request's student.
            final Map<String, String> studentNames = <String, String>{
              for (final Student s in students) s.uid: s.fullName,
            };

            openEvent = (BuildContext ctx, String eventId) {
              Event? ev;
              for (final Event e in events) {
                if (e.eventId == eventId) {
                  ev = e;
                  break;
                }
              }
              if (ev == null) {
                ScaffoldMessenger.of(ctx)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                      content: Text('Event details are unavailable.')));
                return;
              }
              final String vendorId = ev.vendorId;
              String vendorName = vendorId;
              for (final Vendor v in vendors) {
                if (v.uid == vendorId) {
                  vendorName = v.agencyName;
                  break;
                }
              }
              Navigator.of(ctx).push<void>(MaterialPageRoute<void>(
                builder: (_) => AdminEventDetailScreen(
                  event: ev!,
                  attendanceStream: watchEventAttendance(eventId),
                  enrolledStream: watchEventApplications(eventId),
                  ratingsStream: watchEventRatings(eventId),
                  onOpenStudent: openStudent,
                  vendorName: vendorName,
                  onOpenVendor: (BuildContext c) => openVendor(c, vendorId),
                ),
              ));
            };

            openVendor = (BuildContext ctx, String vendorId) {
              Vendor? vn;
              for (final Vendor v in vendors) {
                if (v.uid == vendorId) {
                  vn = v;
                  break;
                }
              }
              if (vn == null) {
                ScaffoldMessenger.of(ctx)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                      content: Text('Vendor details are unavailable.')));
                return;
              }
              Navigator.of(ctx).push<void>(MaterialPageRoute<void>(
                builder: (_) => AdminVendorDetailScreen(
                  vendor: vn!,
                  eventsStream: watchVendorEvents(vendorId),
                  onOpenEvent: openEvent,
                ),
              ));
            };

            openStudent = (BuildContext ctx, String studentId) {
              Student? st;
              for (final Student s in students) {
                if (s.uid == studentId) {
                  st = s;
                  break;
                }
              }
              if (st == null) {
                ScaffoldMessenger.of(ctx)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                      content: Text('Student details are unavailable.')));
                return;
              }
              Navigator.of(ctx).push<void>(MaterialPageRoute<void>(
                builder: (_) => AdminStudentDetailScreen(
                  student: st!,
                  applicationsStream: watchStudentApplications(studentId),
                  attendanceStream: watchStudentAttendance(studentId),
                  ratingsStream: watchStudentRatings(studentId),
                  createWalletCubit: createWalletCubit,
                  onOpenEvent: openEvent,
                ),
              ));
            };

            return TabBarView(
              children: <Widget>[
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : _StudentList(
                        students: students,
                        onOpenStudent: openStudent,
                      ),
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : _VendorList(
                        vendors: vendors,
                        watchVendorEvents: watchVendorEvents,
                        onOpenEvent: openEvent,
                      ),
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : _EventList(
                        events: events,
                        onOpenEvent: openEvent,
                        onSetApproval: setEventApproval,
                      ),
                AdminWithdrawalsTab(
                  createCubit: createWithdrawalReviewCubit,
                  studentNames: studentNames,
                  onOpenStudent: openStudent,
                ),
                AdminRevenueScreen(
                  createCubit: createAdminRevenueCubit,
                  onOpenEvent: openEvent,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The registered student list (R6.4) with an empty-state indication (R6.9).
class _StudentList extends StatelessWidget {
  const _StudentList({required this.students, required this.onOpenStudent});

  final List<Student> students;
  final void Function(BuildContext context, String studentId) onOpenStudent;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const _EmptyView(message: 'No students are registered.');
    }
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          key: ValueKey<String>('student-${student.uid}'),
          leading: const Icon(Icons.person_outline),
          title: Text(student.fullName),
          subtitle: Text(student.city),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onOpenStudent(context, student.uid),
        );
      },
    );
  }
}

/// The registered vendor list with approval status and approve/reject controls
/// for pending vendors (R6.1, R6.2, R6.5) and an empty-state indication (R6.9).
class _VendorList extends StatelessWidget {
  const _VendorList({
    required this.vendors,
    required this.watchVendorEvents,
    required this.onOpenEvent,
  });

  final List<Vendor> vendors;
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;
  final void Function(BuildContext context, String eventId) onOpenEvent;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return const _EmptyView(message: 'No vendors are registered.');
    }
    return ListView.builder(
      itemCount: vendors.length,
      itemBuilder: (context, index) {
        final vendor = vendors[index];
        final isPending = vendor.approvalStatus == ApprovalStatus.pending;
        return ListTile(
          key: ValueKey<String>('vendor-${vendor.uid}'),
          leading: const Icon(Icons.store_outlined),
          title: Text(vendor.agencyName),
          subtitle: Text(
            '${vendor.fullName} · ${vendor.approvalStatus.wireName}',
          ),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AdminVendorDetailScreen(
                vendor: vendor,
                eventsStream: watchVendorEvents(vendor.uid),
                onOpenEvent: onOpenEvent,
              ),
            ),
          ),
          trailing: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      key: ValueKey<String>('approve-${vendor.uid}'),
                      tooltip: 'Approve',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => context
                          .read<AdminBloc>()
                          .add(VendorApproveRequested(vendor.uid)),
                    ),
                    IconButton(
                      key: ValueKey<String>('reject-${vendor.uid}'),
                      tooltip: 'Reject',
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () => context
                          .read<AdminBloc>()
                          .add(VendorRejectRequested(vendor.uid)),
                    ),
                  ],
                )
              : _StatusChip(label: vendor.approvalStatus.wireName),
        );
      },
    );
  }
}

/// The status filter for the admin event list.
enum _EventFilter { all, active, closed, completed }

/// The event list (R6.6) with a search field and a status filter, each event
/// with its lifecycle status; an empty-state indication when none match (R6.9).
class _EventList extends StatefulWidget {
  const _EventList({
    required this.events,
    required this.onOpenEvent,
    required this.onSetApproval,
  });

  final List<Event> events;
  final void Function(BuildContext context, String eventId) onOpenEvent;
  final SetEventApprovalFn onSetApproval;

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  _EventFilter _filter = _EventFilter.all;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  EventStatus? _target(_EventFilter f) => switch (f) {
        _EventFilter.all => null,
        _EventFilter.active => EventStatus.active,
        _EventFilter.closed => EventStatus.closed,
        _EventFilter.completed => EventStatus.completed,
      };

  /// Approves or rejects [event]. The events list stream re-emits after the
  /// write, so the row's controls update themselves; here we only confirm.
  Future<void> _moderate(
    BuildContext context,
    Event event,
    ApprovalStatus status,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await widget.onSetApproval(event.eventId, status);
    final String message = !ok
        ? 'Could not update the event. Please try again.'
        : status == ApprovalStatus.approved
            ? '"${event.title}" approved and published.'
            : '"${event.title}" rejected.';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return const _EmptyView(message: 'No events exist.');
    }
    final DateTime now = DateTime.now();
    final EventStatus? target = _target(_filter);
    final String q = _query.toLowerCase();
    final List<Event> visible = widget.events.where((Event e) {
      if (target != null && effectiveEventStatus(e, now) != target) {
        return false;
      }
      if (q.isNotEmpty && !e.title.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (String v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search events by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: <Widget>[
              for (final MapEntry<_EventFilter, String> e
                  in const <_EventFilter, String>{
                _EventFilter.all: 'All',
                _EventFilter.active: 'Active',
                _EventFilter.closed: 'Closed',
                _EventFilter.completed: 'Completed',
              }.entries) ...<Widget>[
                ChoiceChip(
                  key: ValueKey<String>('event-filter-${e.key.name}'),
                  label: Text(e.value),
                  selected: _filter == e.key,
                  onSelected: (_) => setState(() => _filter = e.key),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const _EmptyView(
                  message: 'No events match your search or filter.')
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final Event event = visible[index];
                    return _AdminEventTile(
                      event: event,
                      statusLabel: effectiveEventStatus(event, now).wireName,
                      onOpen: () => widget.onOpenEvent(context, event.eventId),
                      onModerate: (ApprovalStatus status) =>
                          _moderate(context, event, status),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A small status label used for vendor approval and event statuses.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

/// One event row in the admin event list. Uses a [Card]+[Column] (not a
/// [ListTile]) so the moderation controls and multi-line badges can lay out
/// freely without hitting ListTile's rigid height constraints.
class _AdminEventTile extends StatelessWidget {
  const _AdminEventTile({
    required this.event,
    required this.statusLabel,
    required this.onOpen,
    required this.onModerate,
  });

  final Event event;
  final String statusLabel;
  final VoidCallback onOpen;
  final void Function(ApprovalStatus status) onModerate;

  @override
  Widget build(BuildContext context) {
    final bool pending = event.approvalStatus == ApprovalStatus.pending;
    final bool rejected = event.approvalStatus == ApprovalStatus.rejected;
    return Card(
      key: ValueKey<String>('event-${event.eventId}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.event_outlined, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.slots} slots • ₹${event.payPerHead.formatted}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _StatusChip(label: statusLabel),
                      if (pending || rejected) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          pending ? 'Pending review' : 'Rejected',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pending
                                ? Colors.orange.shade800
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (pending) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        key: ValueKey<String>('event-approve-${event.eventId}'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => onModerate(ApprovalStatus.approved),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey<String>('event-reject-${event.eventId}'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => onModerate(ApprovalStatus.rejected),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty-state indication conveying that no records are available (R6.9).
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inbox_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
