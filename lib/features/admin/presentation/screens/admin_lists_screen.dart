import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../auth/presentation/widgets/logout_button.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/event_status_policy.dart';
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
    super.key,
  });

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
  });

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: const <Widget>[LogoutButton()],
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
                    : _EventList(events: events, onOpenEvent: openEvent),
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
  const _EventList({required this.events, required this.onOpenEvent});

  final List<Event> events;
  final void Function(BuildContext context, String eventId) onOpenEvent;

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
                    return ListTile(
                      key: ValueKey<String>('event-${event.eventId}'),
                      leading: const Icon(Icons.event_outlined),
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.slots} slots • ₹${event.payPerHead.formatted}',
                      ),
                      trailing: _StatusChip(
                        label: effectiveEventStatus(event, now).wireName,
                      ),
                      onTap: () => widget.onOpenEvent(context, event.eventId),
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
