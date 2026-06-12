import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/admin/presentation/bloc/admin_bloc.dart';
import '../features/admin/presentation/screens/admin_lists_screen.dart';
import '../features/admin/presentation/screens/admin_metrics_screen.dart';
import '../features/attendance/presentation/bloc/attendance_bloc.dart';
import '../features/attendance/presentation/screens/attendance_history_screen.dart';
import '../features/auth/presentation/screens/phone_entry_screen.dart';
import '../features/earnings/presentation/bloc/earnings_bloc.dart';
import '../features/earnings/presentation/screens/earnings_screen.dart';
import '../features/events/presentation/bloc/event_discovery_bloc.dart';
import '../features/events/presentation/bloc/event_management_bloc.dart';
import '../features/events/presentation/screens/event_discovery_screen.dart';
import '../features/events/presentation/screens/manage_events_screen.dart';
import '../features/events/presentation/screens/student_dashboard_screen.dart';
import '../features/navigation/domain/entities/destination.dart';
import '../features/profile/domain/entities/vendor.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/bloc/student_profile_cubit.dart';
import '../features/profile/presentation/screens/student_profile_screen.dart';
import '../features/applications/presentation/bloc/student_applications_cubit.dart';
import '../core/error/failure.dart';
import '../core/result/result.dart';
import 'destination_screen_factory.dart';

/// Builds the real feature screen for each [Destination] (R3.1).
///
/// This is the composition-root implementation of [DestinationScreenFactory]:
/// it maps every resolved [Destination] to its feature screen, wiring each
/// screen's BLoC/Cubit from the supplied factories so the router stays
/// backend-agnostic. The signed-in user's id is read on demand from
/// [uidProvider] (backed by Firebase Auth in `main`); a destination that needs
/// the user but has no signed-in id falls back to a neutral scaffold rather
/// than crashing.
///
/// The role-based router only ever renders a role's *home* destination plus the
/// shared [Destination.authentication] / [Destination.noRole] screens, so those
/// paths are wired to their full screens; the remaining role destinations are
/// mapped to a reasonable existing screen so navigation extensions added later
/// have a working target.
class AppDestinationScreenFactory {
  AppDestinationScreenFactory({
    required this.uidProvider,
    required this.profileRepository,
    required this.createEventDiscoveryBloc,
    required this.createStudentApplicationsCubit,
    required this.createAttendanceBloc,
    required this.createStudentProfileCubit,
    required this.createEarningsBloc,
    required this.createEventManagementBloc,
    required this.createAdminBloc,
  });

  /// Resolves the signed-in user's id, or `null` when unavailable.
  final String? Function() uidProvider;

  /// Loads vendor profiles for the vendor home (R5.2).
  final ProfileRepository profileRepository;

  final EventDiscoveryBloc Function() createEventDiscoveryBloc;
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;
  final AttendanceBloc Function() createAttendanceBloc;
  final StudentProfileCubit Function() createStudentProfileCubit;
  final EarningsBloc Function() createEarningsBloc;
  final EventManagementBloc Function() createEventManagementBloc;
  final AdminBloc Function() createAdminBloc;

  /// The [DestinationScreenFactory] the router calls to render [destination].
  Widget build(Destination destination) {
    switch (destination) {
      case Destination.authentication:
        // The ambient AuthBloc is provided above the router, so the phone-entry
        // screen reads it from context (R3.4).
        return const PhoneEntryScreen();

      case Destination.noRole:
        return const _NoRoleScreen();

      // --- Student ---
      case Destination.studentDashboard:
        return _withUid(
          (String uid) => StudentDashboardScreen(
            studentId: uid,
            createEventDiscoveryBloc: createEventDiscoveryBloc,
            createStudentApplicationsCubit: createStudentApplicationsCubit,
            createAttendanceBloc: createAttendanceBloc,
            createStudentProfileCubit: createStudentProfileCubit,
          ),
        );
      case Destination.studentDiscovery:
        return EventDiscoveryScreen(createBloc: createEventDiscoveryBloc);
      case Destination.studentAttendance:
        return _withUid(
          (String uid) => BlocProvider<AttendanceBloc>(
            create: (_) =>
                createAttendanceBloc()..add(HistoryWatchStarted(uid)),
            child: AttendanceHistoryScreen(studentId: uid),
          ),
        );
      case Destination.studentEarnings:
        return _withUid(
          (String uid) => EarningsScreen(
            studentId: uid,
            createBloc: createEarningsBloc,
          ),
        );
      case Destination.studentProfile:
        return _withUid(
          (String uid) => StudentProfileScreen(
            uid: uid,
            createCubit: createStudentProfileCubit,
          ),
        );
      case Destination.studentReports:
        return const _PendingScreen(title: 'Report an issue');

      // --- Vendor ---
      case Destination.vendorEvents:
        return _withUid(
          (String uid) => _VendorEventsLoader(
            uid: uid,
            profileRepository: profileRepository,
            createBloc: createEventManagementBloc,
          ),
        );
      case Destination.vendorApplicants:
        return const _PendingScreen(title: 'Applicants');
      case Destination.vendorAttendance:
        return const _PendingScreen(title: 'Attendance');
      case Destination.vendorProfile:
        return const _PendingScreen(title: 'Profile');
      case Destination.vendorReports:
        return const _PendingScreen(title: 'Report an issue');

      // --- Admin ---
      case Destination.adminDashboard:
        return AdminMetricsScreen(createBloc: createAdminBloc);
      case Destination.adminVendorApprovals:
      case Destination.adminStudents:
      case Destination.adminVendors:
      case Destination.adminEvents:
        return AdminListsScreen(createBloc: createAdminBloc);
      case Destination.adminReports:
        return const _PendingScreen(title: 'Reports');
    }
  }

  /// Renders [builder] with the signed-in user's id, or a sign-in fallback when
  /// no user is available.
  Widget _withUid(Widget Function(String uid) builder) {
    final String? uid = uidProvider();
    if (uid == null || uid.isEmpty) {
      return const _NoRoleScreen();
    }
    return builder(uid);
  }
}

/// Loads the signed-in vendor's profile, then renders the manage-events home
/// (R5.2). Creation is gated on the loaded vendor's approval status (R5.1).
class _VendorEventsLoader extends StatelessWidget {
  const _VendorEventsLoader({
    required this.uid,
    required this.profileRepository,
    required this.createBloc,
  });

  final String uid;
  final ProfileRepository profileRepository;
  final EventManagementBloc Function() createBloc;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<Vendor, Failure>>(
      future: profileRepository.getVendor(uid),
      builder: (
        BuildContext context,
        AsyncSnapshot<Result<Vendor, Failure>> snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final Result<Vendor, Failure>? result = snapshot.data;
        if (result == null) {
          return const _PendingScreen(title: 'Manage events');
        }
        return result.fold(
          (Vendor vendor) =>
              ManageEventsScreen(vendor: vendor, createBloc: createBloc),
          (_) => const _PendingScreen(title: 'Manage events'),
        );
      },
    );
  }
}

/// The "no valid role assigned" destination (R3.3).
class _NoRoleScreen extends StatelessWidget {
  const _NoRoleScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EventXIndia')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your account has no role assigned yet. '
            'Please complete profile setup or contact support.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// A neutral placeholder for destinations whose dedicated screen needs context
/// (e.g. a selected event) that the router does not yet supply.
class _PendingScreen extends StatelessWidget {
  const _PendingScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
