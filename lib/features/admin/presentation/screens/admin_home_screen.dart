import 'package:flutter/material.dart';

import '../../../applications/domain/entities/application.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../events/domain/entities/event.dart';
import '../../../ratings/domain/entities/rating_entry.dart';
import '../../../wallet/presentation/bloc/wallet_cubit.dart';
import '../../../wallet/presentation/bloc/withdrawal_review_cubit.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_revenue_cubit.dart';
import 'admin_lists_screen.dart';
import 'admin_metrics_screen.dart';

/// The admin's home shell (R6): a bottom-nav host giving the admin access to
/// both the **Dashboard** (metrics) and **Management** views.
///
/// Management is [AdminListsScreen], whose tabs cover Students / Vendors /
/// Events and the wallet **Withdrawals** review. Each destination owns its own
/// BLoC/Cubit built from the injected factories, so this shell only supplies
/// navigation chrome (mirroring the student dashboard's structure).
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
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

  /// Factory for the [AdminBloc] backing the metrics and lists views.
  final AdminBloc Function() createBloc;

  /// Factory for the Revenue tab's [AdminRevenueCubit].
  final AdminRevenueCubit Function() createAdminRevenueCubit;

  /// Factory for the Withdrawals tab's [WithdrawalReviewCubit].
  final WithdrawalReviewCubit Function() createWithdrawalReviewCubit;

  /// Factory for the [WalletCubit] used to show a student's wallet.
  final WalletCubit Function() createWalletCubit;

  /// Per-event streams backing the admin event drill-down.
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;

  /// Per-vendor / per-student streams backing the vendor and student
  /// drill-downs.
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;
  final Stream<List<Application>> Function(String studentId)
      watchStudentApplications;
  final Stream<List<AttendanceRecord>> Function(String studentId)
      watchStudentAttendance;

  /// Per-event / per-student ratings streams backing the admin drill-downs.
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  late final List<Widget> _tabs = <Widget>[
    AdminMetricsScreen(createBloc: widget.createBloc),
    AdminListsScreen(
      createBloc: widget.createBloc,
      createAdminRevenueCubit: widget.createAdminRevenueCubit,
      createWithdrawalReviewCubit: widget.createWithdrawalReviewCubit,
      createWalletCubit: widget.createWalletCubit,
      watchEventAttendance: widget.watchEventAttendance,
      watchEventApplications: widget.watchEventApplications,
      watchVendorEvents: widget.watchVendorEvents,
      watchStudentApplications: widget.watchStudentApplications,
      watchStudentAttendance: widget.watchStudentAttendance,
      watchEventRatings: widget.watchEventRatings,
      watchStudentRatings: widget.watchStudentRatings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Management',
          ),
        ],
      ),
    );
  }
}
