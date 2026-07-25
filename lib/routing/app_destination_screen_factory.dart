import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/admin/presentation/bloc/admin_bloc.dart';
import '../features/admin/presentation/bloc/admin_revenue_cubit.dart';
import '../features/admin/presentation/screens/admin_home_screen.dart';
import '../features/admin/presentation/screens/admin_lists_screen.dart';
import '../features/attendance/domain/entities/attendance_record.dart';
import '../features/events/domain/entities/event.dart';
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
import '../features/auth/domain/entities/user_role.dart';
import '../features/navigation/domain/entities/destination.dart';
import '../features/profile/domain/entities/vendor.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/bloc/registration_bloc.dart';
import '../features/profile/presentation/bloc/student_profile_cubit.dart';
import '../features/profile/presentation/screens/student_profile_screen.dart';
import '../features/profile/presentation/screens/student_registration_screen.dart';
import '../features/profile/presentation/screens/vendor_registration_screen.dart';
import '../features/applications/domain/entities/application.dart';
import '../features/applications/presentation/bloc/application_bloc.dart';
import '../features/applications/presentation/bloc/student_applications_cubit.dart';
import '../features/wallet/presentation/bloc/wallet_cubit.dart';
import '../features/wallet/presentation/bloc/withdrawal_review_cubit.dart';
import '../features/ratings/domain/entities/rating_entry.dart';
import '../core/error/failure.dart';
import '../core/result/result.dart';
import '../core/value_objects/rating.dart';
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
    required this.phoneProvider,
    required this.profileRepository,
    required this.createEventDiscoveryBloc,
    required this.createApplicationBloc,
    required this.createStudentApplicationsCubit,
    required this.createAttendanceBloc,
    required this.createStudentProfileCubit,
    required this.createEarningsBloc,
    required this.createEventManagementBloc,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.watchVendorEvents,
    required this.watchStudentApplications,
    required this.watchStudentAttendance,
    required this.createAdminBloc,
    required this.createAdminRevenueCubit,
    required this.createWithdrawalReviewCubit,
    required this.createWalletCubit,
    required this.createRegistrationBloc,
    required this.getEvent,
    required this.watchStudentRatings,
    required this.watchEventRatings,
    required this.rateStudent,
  });

  /// Resolves the signed-in user's id, or `null` when unavailable.
  final String? Function() uidProvider;

  /// Resolves the signed-in user's verified phone (E.164, e.g. `+919876543210`),
  /// or `null` when unavailable. Used to prefill registration so the user need
  /// not re-enter the number they just logged in with.
  final String? Function() phoneProvider;

  /// Loads vendor profiles for the vendor home (R5.2).
  final ProfileRepository profileRepository;

  final EventDiscoveryBloc Function() createEventDiscoveryBloc;

  /// Factory for the [ApplicationBloc] shared by the student apply action and
  /// the vendor applicant-review screen (R8.6, R5.3–R5.5).
  final ApplicationBloc Function() createApplicationBloc;
  final StudentApplicationsCubit Function() createStudentApplicationsCubit;
  final AttendanceBloc Function() createAttendanceBloc;
  final StudentProfileCubit Function() createStudentProfileCubit;
  final EarningsBloc Function() createEarningsBloc;
  final EventManagementBloc Function() createEventManagementBloc;

  /// Streams the attendance records for a single event, backing the vendor's
  /// per-event attendance view (R5.7).
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;

  /// Streams the applications for a single event; the approved ones are the
  /// enrolled students shown in the vendor's attendance view (R5.3, R5.7).
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;

  /// Streams the events owned by a single vendor, backing the admin vendor
  /// drill-down (R6).
  final Stream<List<Event>> Function(String vendorId) watchVendorEvents;

  /// Streams the applications made by a single student, backing the admin
  /// student drill-down (R6).
  final Stream<List<Application>> Function(String studentId)
      watchStudentApplications;

  /// Streams the attendance records of a single student, backing the check-in /
  /// check-out detail on the admin student drill-down (R6).
  final Stream<List<AttendanceRecord>> Function(String studentId)
      watchStudentAttendance;

  final AdminBloc Function() createAdminBloc;

  /// Factory for the admin revenue tab's [AdminRevenueCubit].
  final AdminRevenueCubit Function() createAdminRevenueCubit;

  /// Factory for the admin withdrawal-review tab's [WithdrawalReviewCubit].
  final WithdrawalReviewCubit Function() createWithdrawalReviewCubit;

  /// Factory for the student wallet tab's [WalletCubit].
  final WalletCubit Function() createWalletCubit;

  /// Factory for the [RegistrationBloc] backing the student/vendor registration
  /// forms shown to a signed-in user who has no role yet (R1.5–R1.9, R3.4).
  final RegistrationBloc Function() createRegistrationBloc;

  /// Fetches a single event by id, backing the wallet's event-credit tap →
  /// event-detail navigation (R8.5, R11 wallet).
  final Future<Result<Event, Failure>> Function(String eventId) getEvent;

  /// Streams the ratings a single student has received (student profile
  /// average + per-event, admin student drill-down) (R rating).
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;

  /// Streams the ratings recorded for a single event (vendor attendance +
  /// admin event drill-down) (R rating).
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;

  /// Submits a vendor's one-time rating of a student for an event (R rating).
  final Future<Result<RatingEntry, Failure>> Function({
    required String eventId,
    required String studentId,
    required String vendorId,
    required Rating stars,
  }) rateStudent;

  /// The [DestinationScreenFactory] the router calls to render [destination].
  Widget build(Destination destination) {
    switch (destination) {
      case Destination.authentication:
        // The ambient AuthBloc is provided above the router, so the phone-entry
        // screen reads it from context (R3.4).
        return const PhoneEntryScreen();

      case Destination.noRole:
        // A signed-in user with no role yet completes self-service
        // registration here, which creates their profile + role record and
        // resolves the live session into a role dashboard (R1.5–R1.9, R3.4).
        return _withUid(
          (String uid) => _RegistrationGate(
            uid: uid,
            phone: phoneProvider(),
            createRegistrationBloc: createRegistrationBloc,
          ),
        );

      // --- Student ---
      case Destination.studentDashboard:
        return _withUid(
          (String uid) => StudentDashboardScreen(
            studentId: uid,
            createEventDiscoveryBloc: createEventDiscoveryBloc,
            createApplicationBloc: createApplicationBloc,
            createStudentApplicationsCubit: createStudentApplicationsCubit,
            createAttendanceBloc: createAttendanceBloc,
            createStudentProfileCubit: createStudentProfileCubit,
            createWalletCubit: createWalletCubit,
            getEvent: getEvent,
            watchStudentRatings: watchStudentRatings,
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
            ratingsStream: watchStudentRatings(uid),
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
            createApplicationBloc: createApplicationBloc,
            watchEventAttendance: watchEventAttendance,
            watchEventApplications: watchEventApplications,
            watchEventRatings: watchEventRatings,
            watchStudentRatings: watchStudentRatings,
            rateStudent: rateStudent,
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
        return AdminHomeScreen(
          createBloc: createAdminBloc,
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
        );
      case Destination.adminVendorApprovals:
      case Destination.adminStudents:
      case Destination.adminVendors:
      case Destination.adminEvents:
        return AdminListsScreen(
          createBloc: createAdminBloc,
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
        );
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
    required this.createApplicationBloc,
    required this.watchEventAttendance,
    required this.watchEventApplications,
    required this.watchEventRatings,
    required this.watchStudentRatings,
    required this.rateStudent,
  });

  final String uid;
  final ProfileRepository profileRepository;
  final EventManagementBloc Function() createBloc;
  final ApplicationBloc Function() createApplicationBloc;
  final Stream<List<AttendanceRecord>> Function(String eventId)
      watchEventAttendance;
  final Stream<List<Application>> Function(String eventId)
      watchEventApplications;
  final Stream<List<RatingEntry>> Function(String eventId) watchEventRatings;
  final Stream<List<RatingEntry>> Function(String studentId)
      watchStudentRatings;
  final Future<Result<RatingEntry, Failure>> Function({
    required String eventId,
    required String studentId,
    required String vendorId,
    required Rating stars,
  }) rateStudent;

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
          (Vendor vendor) => ManageEventsScreen(
            vendor: vendor,
            createBloc: createBloc,
            createApplicationBloc: createApplicationBloc,
            watchEventAttendance: watchEventAttendance,
            watchEventApplications: watchEventApplications,
            getStudent: profileRepository.getStudent,
            watchEventRatings: watchEventRatings,
            watchStudentRatings: watchStudentRatings,
            rateStudent: rateStudent,
          ),
          (_) => const _PendingScreen(title: 'Manage events'),
        );
      },
    );
  }
}

/// Self-service registration entry for a signed-in user with no role yet
/// (R1.5–R1.9, R3.4).
///
/// The user picks Student or Vendor, then completes the matching registration
/// form (wrapped in a fresh [RegistrationBloc]). On success the form writes the
/// profile and the `users/{uid}` role record, so the live session resolves into
/// the role's dashboard and the router replaces this gate. Admin accounts are
/// provisioned by the trusted backend, so only the two self-service roles are
/// offered here.
class _RegistrationGate extends StatefulWidget {
  const _RegistrationGate({
    required this.uid,
    required this.phone,
    required this.createRegistrationBloc,
  });

  final String uid;

  /// The signed-in user's verified phone (E.164), prefilled into the form.
  final String? phone;
  final RegistrationBloc Function() createRegistrationBloc;

  @override
  State<_RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<_RegistrationGate> {
  UserRole? _role;

  @override
  Widget build(BuildContext context) {
    final UserRole? role = _role;
    if (role == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complete registration')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Welcome! Tell us who you are to finish setting up your '
                'account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('register-as-student'),
                onPressed: () => setState(() => _role = UserRole.student),
                child: const Text('Register as Student'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey<String>('register-as-vendor'),
                onPressed: () => setState(() => _role = UserRole.vendor),
                child: const Text('Register as Vendor'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider<RegistrationBloc>(
      create: (_) => widget.createRegistrationBloc(),
      child: role == UserRole.student
          ? StudentRegistrationScreen(uid: widget.uid, phone: widget.phone)
          : VendorRegistrationScreen(uid: widget.uid, phone: widget.phone),
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
