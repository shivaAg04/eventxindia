import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../domain/entities/event.dart';
import '../../../applications/presentation/bloc/application_bloc.dart';
import '../../../applications/presentation/bloc/student_applications_cubit.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../profile/presentation/bloc/student_profile_cubit.dart';
import '../../../profile/presentation/screens/student_profile_screen.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../bloc/event_discovery_bloc.dart';
import 'student_active_events_screen.dart';
import 'student_events_screen.dart';

/// Top-level student dashboard hosting the three activity views (R4.1–R4.7).
///
/// A bottom navigation bar switches between:
/// * Active events — streams the active event set (R4.1).
/// * My events — the combined Applied + Attendance destination: an inner tab
///   switcher between the student's applications (with combinable status and
///   active/inactive event filters, R4.2, R4.3) and their per-event attendance
///   with check-in / check-out (R4.4).
/// * Profile — the student's profile data (R4.6).
///
/// Each tab owns its own BLoC/Cubit, built from the injected factories so the
/// dashboard stays backend-agnostic (presentation → domain only). Empty-state
/// and read-failure indications are rendered by the individual tab screens
/// (R4.7).
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({
    required this.studentId,
    required this.createEventDiscoveryBloc,
    required this.createApplicationBloc,
    required this.createStudentApplicationsCubit,
    required this.createAttendanceBloc,
    required this.createStudentProfileCubit,
    required this.createWalletCubit,
    required this.getEvent,
    required this.watchStudentRatings,
    super.key,
  });

  /// The id of the signed-in student.
  final String studentId;

  /// Factory for the active-events tab's [EventDiscoveryBloc].
  final EventDiscoveryBloc Function() createEventDiscoveryBloc;

  /// Factory for the [ApplicationBloc] backing the apply action reached from the
  /// active-events tab (R8.6).
  final ApplicationBloc Function() createApplicationBloc;

  /// Factory for the applied/approved tabs' [StudentApplicationsCubit].
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;

  /// Factory for the attendance tab's [AttendanceBloc].
  final AttendanceBloc Function() createAttendanceBloc;

  /// Factory for the profile tab's [StudentProfileCubit].
  final StudentProfileCubit Function() createStudentProfileCubit;

  /// Factory for the wallet tab's [WalletCubit].
  final WalletCubit Function() createWalletCubit;

  /// Fetches a single event by id so a wallet event credit can open the
  /// event-detail screen (R8.5).
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

  /// Streams the ratings this student has received (profile average +
  /// per-event on My events) (R rating).
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _index = 0;

  late final List<Widget> _tabs = <Widget>[
    StudentActiveEventsScreen(
      createBloc: widget.createEventDiscoveryBloc,
      studentId: widget.studentId,
      createApplicationBloc: widget.createApplicationBloc,
      createStudentApplicationsCubit: widget.createStudentApplicationsCubit,
    ),
    StudentEventsScreen(
      studentId: widget.studentId,
      createStudentApplicationsCubit: widget.createStudentApplicationsCubit,
      createAttendanceBloc: widget.createAttendanceBloc,
      getEvent: widget.getEvent,
      ratingsStream: widget.watchStudentRatings(widget.studentId),
    ),
    WalletScreen(
      studentId: widget.studentId,
      createCubit: widget.createWalletCubit,
      getEvent: widget.getEvent,
    ),
    StudentProfileScreen(
      uid: widget.studentId,
      createCubit: widget.createStudentProfileCubit,
      ratingsStream: widget.watchStudentRatings(widget.studentId),
      createWalletCubit: widget.createWalletCubit,
      createStudentApplicationsCubit: widget.createStudentApplicationsCubit,
    ),
  ];

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(Icons.event_outlined, Icons.event, 'Active'),
    _NavItem(Icons.assignment_outlined, Icons.assignment, 'My events'),
    _NavItem(Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet, 'Wallet'),
    _NavItem(Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _PillBottomNav(
        index: _index,
        items: _items,
        onSelected: (int value) => setState(() => _index = value),
      ),
    );
  }
}

/// One entry in the pill bottom nav.
class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A floating white nav bar: each item shows its icon + label; the selected
/// item is red with a short underline bar (matching the design).
class _PillBottomNav extends StatelessWidget {
  const _PillBottomNav({
    required this.index,
    required this.items,
    required this.onSelected,
  });

  final int index;
  final List<_NavItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A101828),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: _NavCell(
                  item: items[i],
                  selected: i == index,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(selected ? item.selectedIcon : item.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            // The short underline marker under the selected item.
            Container(
              height: 3,
              width: selected ? 18 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
