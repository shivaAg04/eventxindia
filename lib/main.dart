import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bootstrap/device_token_registrar.dart';
import 'core/data/firebase_initializer.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/admin/presentation/bloc/admin_bloc.dart';
import 'features/admin/presentation/bloc/admin_revenue_cubit.dart';
import 'features/applications/presentation/bloc/application_bloc.dart';
import 'features/applications/domain/usecases/watch_event_applications.dart';
import 'features/applications/domain/usecases/watch_student_applications.dart';
import 'features/attendance/domain/repositories/attendance_repository.dart';
import 'features/attendance/domain/usecases/watch_event_attendance.dart';
import 'features/events/domain/usecases/get_event.dart';
import 'features/events/domain/usecases/set_event_approval.dart';
import 'features/events/domain/usecases/watch_vendor_events.dart';
import 'core/value_objects/approval_status.dart';
import 'core/value_objects/rating.dart';
import 'features/config/presentation/bloc/platform_config_cubit.dart';
import 'features/staff/domain/repositories/staff_repository.dart';
import 'features/staff/presentation/bloc/staff_cubit.dart';
import 'features/ratings/domain/usecases/rate_student.dart';
import 'features/ratings/domain/usecases/watch_event_ratings.dart';
import 'features/ratings/domain/usecases/watch_student_ratings.dart';
import 'features/attendance/presentation/bloc/attendance_bloc.dart';
import 'features/auth/domain/entities/session_state.dart' as session;
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/earnings/presentation/bloc/earnings_bloc.dart';
import 'features/events/presentation/bloc/event_discovery_bloc.dart';
import 'features/events/presentation/bloc/event_management_bloc.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/presentation/bloc/registration_bloc.dart';
import 'features/profile/presentation/bloc/student_profile_cubit.dart';
import 'features/applications/presentation/bloc/student_applications_cubit.dart';
import 'features/wallet/presentation/bloc/wallet_cubit.dart';
import 'features/wallet/presentation/bloc/withdrawal_review_cubit.dart';
import 'routing/app_destination_screen_factory.dart';
import 'routing/routing.dart';

Future<void> main() async {
  // Ensure the binding is ready before any async bootstrap work.
  WidgetsFlutterBinding.ensureInitialized();

  // Bring up the Firebase backend before wiring the data layer. The
  // initializer is idempotent and tolerates a missing generated
  // `firebase_options.dart`, falling back to the platform's native config.
  //
  // When no Firebase configuration is present (e.g. running on an emulator
  // without `google-services.json` / `GoogleService-Info.plist`), init and DI
  // wiring can fail. We swallow that here so the app still boots to the auth
  // screen rather than crashing on launch; the data layer simply won't have a
  // live backend until configuration is added.
  try {
    await initializeFirebase();

    // DEBUG ONLY: skip Play Integrity / reCAPTCHA app-verification so Firebase
    // "test phone numbers" (Console → Auth → Phone → numbers for testing) log in
    // instantly without a registered SHA fingerprint. On Android the SDK
    // otherwise runs app verification even for test numbers, which hangs when no
    // SHA / reCAPTCHA is configured (the OTP screen never appears). This has NO
    // effect on release builds and does NOT affect real phone numbers.
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }

    await configureDependencies();
  } catch (error, stackTrace) {
    debugPrint('EventXIndia bootstrap skipped backend wiring: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const EventXIndiaApp());
}

/// Root application widget.
///
/// Hosts the app-wide [AuthBloc] (started watching the session) and the
/// role-based [RoleRouter], which renders the start destination for the current
/// session (R3.1, R3.4). After authentication it registers this device's FCM
/// token for push delivery (R13.7).
class EventXIndiaApp extends StatelessWidget {
  const EventXIndiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventXIndia',
      debugShowCheckedModeBanner: false,
      // The product is light by design; wire the one theme as both slots so it
      // holds regardless of the platform brightness setting.
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      // Paint the soft light canvas behind every screen so the whole app shares
      // the same base without each screen opting in.
      builder: (BuildContext context, Widget? child) => DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.canvas),
        child: child,
      ),
      home: const _AppRoot(),
    );
  }
}

/// Provides the ambient [AuthBloc] and hosts the role-based router.
///
/// The router is decoupled from concrete screens through a
/// [DestinationScreenFactory]; when DI has been configured we supply the real
/// [AppDestinationScreenFactory], otherwise (e.g. in the widget smoke test that
/// pumps [EventXIndiaApp] without bootstrapping) we fall back to the
/// placeholder factory so the widget tree still builds.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<AuthBloc>()) {
      // DI not configured (smoke/widget test): render the router with the
      // placeholder factory and an inert session source so it does not require
      // an ambient AuthBloc.
      return const RoleRouter(sessionStream: Stream<session.SessionState>.empty());
    }

    return BlocProvider<AuthBloc>(
      create: (_) => getIt<AuthBloc>()..add(const SessionWatchStarted()),
      child: const _RoutedApp(),
    );
  }
}

class _RoutedApp extends StatefulWidget {
  const _RoutedApp();

  @override
  State<_RoutedApp> createState() => _RoutedAppState();
}

class _RoutedAppState extends State<_RoutedApp> {
  late final AppDestinationScreenFactory _factory;
  late final DeviceTokenRegistrar _tokenRegistrar;

  @override
  void initState() {
    super.initState();
    _factory = AppDestinationScreenFactory(
      uidProvider: () => FirebaseAuth.instance.currentUser?.uid,
      phoneProvider: () => FirebaseAuth.instance.currentUser?.phoneNumber,
      profileRepository: getIt<ProfileRepository>(),
      createEventDiscoveryBloc: () => getIt<EventDiscoveryBloc>(),
      createApplicationBloc: () => getIt<ApplicationBloc>(),
      createStudentApplicationsCubit: () => getIt<StudentApplicationsCubit>(),
      createAttendanceBloc: () => getIt<AttendanceBloc>(),
      createStudentProfileCubit: () => getIt<StudentProfileCubit>(),
      createEarningsBloc: () => getIt<EarningsBloc>(),
      createEventManagementBloc: () => getIt<EventManagementBloc>(),
      watchEventAttendance: (String eventId) =>
          getIt<WatchEventAttendance>()(eventId),
      watchEventApplications: (String eventId) =>
          getIt<WatchEventApplications>()(eventId: eventId),
      watchVendorEvents: (String vendorId) =>
          getIt<WatchVendorEvents>()(vendorId),
      watchStudentApplications: (String studentId) =>
          getIt<WatchStudentApplications>()(studentId: studentId),
      watchStudentAttendance: (String studentId) =>
          getIt<AttendanceRepository>().watchByStudent(studentId),
      createAdminBloc: () => getIt<AdminBloc>(),
      createAdminRevenueCubit: () => getIt<AdminRevenueCubit>(),
      createWithdrawalReviewCubit: () => getIt<WithdrawalReviewCubit>(),
      createWalletCubit: () => getIt<WalletCubit>(),
      createRegistrationBloc: () => getIt<RegistrationBloc>(),
      getEvent: (String eventId) => getIt<GetEvent>()(eventId),
      watchStudentRatings: (String studentId) =>
          getIt<WatchStudentRatings>()(studentId),
      watchEventRatings: (String eventId) =>
          getIt<WatchEventRatings>()(eventId),
      rateStudent: ({
        required String eventId,
        required String studentId,
        required String vendorId,
        required Rating stars,
      }) =>
          getIt<RateStudent>()(
        eventId: eventId,
        studentId: studentId,
        vendorId: vendorId,
        stars: stars,
      ),
      createPlatformConfigCubit: () => getIt<PlatformConfigCubit>(),
      createStaffCubit: () => getIt<StaffCubit>(),
      findStaffByPhone: (String phoneE164) =>
          getIt<StaffRepository>().findByPhone(phoneE164),
      setEventApproval: (String eventId, ApprovalStatus status) async {
        final result = await getIt<SetEventApproval>()(
          eventId: eventId,
          status: status,
        );
        return result.isOk;
      },
    );
    _tokenRegistrar = DeviceTokenRegistrar(
      adminRepository: getIt<AdminRepository>(),
      uidProvider: () => FirebaseAuth.instance.currentUser?.uid,
      tokenProvider: () => FirebaseMessaging.instance.getToken(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (AuthState previous, AuthState current) =>
          current is Authenticated && previous is! Authenticated,
      listener: (BuildContext context, AuthState state) {
        // Best-effort device-token registration after authentication (R13.7).
        unawaited(_tokenRegistrar.register());
      },
      child: RoleRouter(screenFactory: _factory.build),
    );
  }
}
