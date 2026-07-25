// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_messaging/firebase_messaging.dart' as _i892;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/admin/data/datasources/firestore_admin_data_source.dart'
    as _i489;
import '../../features/admin/data/datasources/firestore_metrics_data_source.dart'
    as _i701;
import '../../features/admin/data/repositories/firestore_admin_repository_impl.dart'
    as _i420;
import '../../features/admin/data/services/firestore_metrics_service.dart'
    as _i173;
import '../../features/admin/domain/repositories/admin_repository.dart'
    as _i583;
import '../../features/admin/domain/services/metrics_service.dart' as _i219;
import '../../features/admin/domain/usecases/approve_vendor.dart' as _i864;
import '../../features/admin/domain/usecases/get_metrics.dart' as _i730;
import '../../features/admin/domain/usecases/list_events.dart' as _i481;
import '../../features/admin/domain/usecases/list_reports.dart' as _i137;
import '../../features/admin/domain/usecases/list_students.dart' as _i24;
import '../../features/admin/domain/usecases/list_vendors.dart' as _i792;
import '../../features/admin/domain/usecases/reject_vendor.dart' as _i135;
import '../../features/admin/presentation/bloc/admin_bloc.dart' as _i55;
import '../../features/admin/presentation/bloc/admin_revenue_cubit.dart'
    as _i982;
import '../../features/applications/data/datasources/firestore_application_data_source.dart'
    as _i36;
import '../../features/applications/data/repositories/firestore_application_repository_impl.dart'
    as _i574;
import '../../features/applications/domain/repositories/application_repository.dart'
    as _i873;
import '../../features/applications/domain/usecases/apply_to_event.dart'
    as _i803;
import '../../features/applications/domain/usecases/decide_application.dart'
    as _i702;
import '../../features/applications/domain/usecases/watch_event_applications.dart'
    as _i719;
import '../../features/applications/domain/usecases/watch_student_applications.dart'
    as _i566;
import '../../features/applications/presentation/bloc/application_bloc.dart'
    as _i876;
import '../../features/applications/presentation/bloc/student_applications_cubit.dart'
    as _i726;
import '../../features/attendance/data/datasources/firestore_attendance_data_source.dart'
    as _i141;
import '../../features/attendance/data/repositories/firestore_attendance_repository_impl.dart'
    as _i724;
import '../../features/attendance/domain/repositories/attendance_repository.dart'
    as _i477;
import '../../features/attendance/domain/usecases/check_in.dart' as _i293;
import '../../features/attendance/domain/usecases/check_out.dart' as _i25;
import '../../features/attendance/domain/usecases/generate_attendance_code.dart'
    as _i794;
import '../../features/attendance/domain/usecases/watch_event_attendance.dart'
    as _i462;
import '../../features/attendance/presentation/bloc/attendance_bloc.dart'
    as _i700;
import '../../features/attendance/presentation/bloc/device_location_service.dart'
    as _i232;
import '../../features/auth/data/datasources/firebase_auth_data_source.dart'
    as _i492;
import '../../features/auth/data/repositories/firebase_auth_repository_impl.dart'
    as _i996;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/domain/usecases/request_otp.dart' as _i474;
import '../../features/auth/domain/usecases/sign_out.dart' as _i568;
import '../../features/auth/domain/usecases/verify_otp.dart' as _i975;
import '../../features/auth/domain/usecases/watch_session.dart' as _i725;
import '../../features/auth/presentation/bloc/auth_bloc.dart' as _i797;
import '../../features/earnings/data/datasources/firestore_earnings_data_source.dart'
    as _i799;
import '../../features/earnings/data/repositories/firestore_earnings_repository_impl.dart'
    as _i619;
import '../../features/earnings/data/services/firestore_earnings_service.dart'
    as _i89;
import '../../features/earnings/domain/repositories/earnings_repository.dart'
    as _i1028;
import '../../features/earnings/domain/services/earnings_service.dart' as _i326;
import '../../features/earnings/domain/usecases/get_earnings.dart' as _i176;
import '../../features/earnings/presentation/bloc/earnings_bloc.dart' as _i142;
import '../../features/events/data/datasources/firestore_event_data_source.dart'
    as _i962;
import '../../features/events/data/repositories/firestore_event_repository_impl.dart'
    as _i618;
import '../../features/events/domain/repositories/event_repository.dart'
    as _i199;
import '../../features/events/domain/usecases/change_event_status.dart'
    as _i920;
import '../../features/events/domain/usecases/create_event.dart' as _i539;
import '../../features/events/domain/usecases/get_event.dart' as _i546;
import '../../features/events/domain/usecases/search_active_events.dart'
    as _i776;
import '../../features/events/domain/usecases/watch_active_events.dart'
    as _i1037;
import '../../features/events/domain/usecases/watch_vendor_events.dart'
    as _i1019;
import '../../features/events/presentation/bloc/event_discovery_bloc.dart'
    as _i785;
import '../../features/events/presentation/bloc/event_management_bloc.dart'
    as _i653;
import '../../features/navigation/domain/usecases/authorize.dart' as _i64;
import '../../features/navigation/domain/usecases/resolve_start_destination.dart'
    as _i313;
import '../../features/notifications/data/datasources/firebase_notification_data_source.dart'
    as _i317;
import '../../features/notifications/data/repositories/firebase_notification_service_impl.dart'
    as _i961;
import '../../features/notifications/domain/services/notification_service.dart'
    as _i569;
import '../../features/profile/data/repositories/firebase_storage_repository_impl.dart'
    as _i702;
import '../../features/profile/data/repositories/firestore_profile_repository_impl.dart'
    as _i652;
import '../../features/profile/domain/repositories/profile_repository.dart'
    as _i894;
import '../../features/profile/domain/repositories/storage_repository.dart'
    as _i50;
import '../../features/profile/presentation/bloc/registration_bloc.dart'
    as _i671;
import '../../features/profile/presentation/bloc/student_profile_cubit.dart'
    as _i30;
import '../../features/ratings/data/datasources/firestore_rating_data_source.dart'
    as _i648;
import '../../features/ratings/data/repositories/firestore_rating_repository_impl.dart'
    as _i63;
import '../../features/ratings/domain/repositories/rating_repository.dart'
    as _i1059;
import '../../features/ratings/domain/usecases/rate_student.dart' as _i939;
import '../../features/ratings/domain/usecases/watch_event_ratings.dart'
    as _i569;
import '../../features/ratings/domain/usecases/watch_student_ratings.dart'
    as _i692;
import '../../features/reports/data/datasources/firestore_report_data_source.dart'
    as _i621;
import '../../features/reports/data/repositories/firestore_report_repository_impl.dart'
    as _i718;
import '../../features/reports/domain/repositories/report_repository.dart'
    as _i939;
import '../../features/reports/domain/usecases/list_reports.dart' as _i517;
import '../../features/reports/domain/usecases/submit_report.dart' as _i684;
import '../../features/reports/presentation/bloc/report_bloc.dart' as _i652;
import '../../features/wallet/data/datasources/firestore_withdrawal_data_source.dart'
    as _i1034;
import '../../features/wallet/data/repositories/firestore_wallet_repository_impl.dart'
    as _i966;
import '../../features/wallet/domain/repositories/wallet_repository.dart'
    as _i571;
import '../../features/wallet/domain/usecases/decide_withdrawal.dart' as _i470;
import '../../features/wallet/domain/usecases/request_withdrawal.dart' as _i418;
import '../../features/wallet/domain/usecases/watch_all_withdrawals.dart'
    as _i575;
import '../../features/wallet/domain/usecases/watch_student_withdrawals.dart'
    as _i390;
import '../../features/wallet/presentation/bloc/wallet_cubit.dart' as _i558;
import '../../features/wallet/presentation/bloc/withdrawal_review_cubit.dart'
    as _i922;
import 'register_module.dart' as _i291;
import 'use_case_module.dart' as _i1054;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt initInjection({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    final useCaseModule = _$UseCaseModule();
    gh.lazySingleton<_i59.FirebaseAuth>(() => registerModule.firebaseAuth);
    gh.lazySingleton<_i974.FirebaseFirestore>(
      () => registerModule.firebaseFirestore,
    );
    gh.lazySingleton<_i457.FirebaseStorage>(
      () => registerModule.firebaseStorage,
    );
    gh.lazySingleton<_i892.FirebaseMessaging>(
      () => registerModule.firebaseMessaging,
    );
    gh.lazySingleton<_i776.SearchActiveEvents>(
      () => useCaseModule.searchActiveEvents(),
    );
    gh.lazySingleton<_i64.Authorize>(() => useCaseModule.authorize());
    gh.lazySingleton<_i313.ResolveStartDestination>(
      () => useCaseModule.resolveStartDestination(),
    );
    gh.factory<_i489.FirestoreAdminDataSource>(
      () => _i489.FirestoreAdminDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i701.FirestoreMetricsDataSource>(
      () => _i701.FirestoreMetricsDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i36.FirestoreApplicationDataSource>(
      () => _i36.FirestoreApplicationDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i141.FirestoreAttendanceDataSource>(
      () => _i141.FirestoreAttendanceDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i799.FirestoreEarningsDataSource>(
      () => _i799.FirestoreEarningsDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i962.FirestoreEventDataSource>(
      () => _i962.FirestoreEventDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i648.FirestoreRatingDataSource>(
      () => _i648.FirestoreRatingDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i621.FirestoreReportDataSource>(
      () => _i621.FirestoreReportDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.factory<_i1034.FirestoreWithdrawalDataSource>(
      () => _i1034.FirestoreWithdrawalDataSource(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i50.StorageRepository>(
      () => _i702.FirebaseStorageRepositoryImpl(gh<_i457.FirebaseStorage>()),
    );
    gh.lazySingleton<_i583.AdminRepository>(
      () => _i420.FirestoreAdminRepositoryImpl(
        gh<_i489.FirestoreAdminDataSource>(),
      ),
    );
    gh.lazySingleton<_i477.AttendanceRepository>(
      () => _i724.FirestoreAttendanceRepositoryImpl(
        gh<_i141.FirestoreAttendanceDataSource>(),
      ),
    );
    gh.factory<_i492.FirebaseAuthDataSource>(
      () => _i492.FirebaseAuthDataSource.inject(
        gh<_i59.FirebaseAuth>(),
        firestore: gh<_i974.FirebaseFirestore>(),
      ),
    );
    gh.factory<_i232.DeviceLocationService>(
      () => const _i232.GeolocatorDeviceLocationService(),
    );
    gh.lazySingleton<_i787.AuthRepository>(
      () => _i996.FirebaseAuthRepositoryImpl.inject(
        gh<_i492.FirebaseAuthDataSource>(),
      ),
    );
    gh.lazySingleton<_i199.EventRepository>(
      () => _i618.FirestoreEventRepositoryImpl(
        gh<_i962.FirestoreEventDataSource>(),
      ),
    );
    gh.lazySingleton<_i864.ApproveVendor>(
      () => useCaseModule.approveVendor(gh<_i583.AdminRepository>()),
    );
    gh.lazySingleton<_i135.RejectVendor>(
      () => useCaseModule.rejectVendor(gh<_i583.AdminRepository>()),
    );
    gh.lazySingleton<_i24.ListStudents>(
      () => useCaseModule.listStudents(gh<_i583.AdminRepository>()),
    );
    gh.lazySingleton<_i792.ListVendors>(
      () => useCaseModule.listVendors(gh<_i583.AdminRepository>()),
    );
    gh.lazySingleton<_i481.ListEvents>(
      () => useCaseModule.listEvents(gh<_i583.AdminRepository>()),
    );
    gh.lazySingleton<_i137.ListReports>(
      () => useCaseModule.adminListReports(gh<_i583.AdminRepository>()),
    );
    gh.lazySingleton<_i571.WalletRepository>(
      () => _i966.FirestoreWalletRepositoryImpl(
        gh<_i1034.FirestoreWithdrawalDataSource>(),
      ),
    );
    gh.lazySingleton<_i219.MetricsService>(
      () =>
          _i173.FirestoreMetricsService(gh<_i701.FirestoreMetricsDataSource>()),
    );
    gh.factory<_i982.AdminRevenueCubit>(
      () => _i982.AdminRevenueCubit(
        gh<_i583.AdminRepository>(),
        gh<_i477.AttendanceRepository>(),
      ),
    );
    gh.lazySingleton<_i1059.RatingRepository>(
      () => _i63.FirestoreRatingRepositoryImpl(
        gh<_i648.FirestoreRatingDataSource>(),
      ),
    );
    gh.lazySingleton<_i873.ApplicationRepository>(
      () => _i574.FirestoreApplicationRepositoryImpl(
        gh<_i36.FirestoreApplicationDataSource>(),
      ),
    );
    gh.lazySingleton<_i939.ReportRepository>(
      () => _i718.FirestoreReportRepositoryImpl(
        gh<_i621.FirestoreReportDataSource>(),
      ),
    );
    gh.factory<_i317.FirebaseNotificationDataSource>(
      () => _i317.FirebaseNotificationDataSource(
        gh<_i974.FirebaseFirestore>(),
        messaging: gh<_i892.FirebaseMessaging>(),
      ),
    );
    gh.lazySingleton<_i939.RateStudent>(
      () => useCaseModule.rateStudent(gh<_i1059.RatingRepository>()),
    );
    gh.lazySingleton<_i692.WatchStudentRatings>(
      () => useCaseModule.watchStudentRatings(gh<_i1059.RatingRepository>()),
    );
    gh.lazySingleton<_i569.WatchEventRatings>(
      () => useCaseModule.watchEventRatings(gh<_i1059.RatingRepository>()),
    );
    gh.lazySingleton<_i418.RequestWithdrawal>(
      () => useCaseModule.requestWithdrawal(gh<_i571.WalletRepository>()),
    );
    gh.lazySingleton<_i470.DecideWithdrawal>(
      () => useCaseModule.decideWithdrawal(gh<_i571.WalletRepository>()),
    );
    gh.lazySingleton<_i390.WatchStudentWithdrawals>(
      () => useCaseModule.watchStudentWithdrawals(gh<_i571.WalletRepository>()),
    );
    gh.lazySingleton<_i575.WatchAllWithdrawals>(
      () => useCaseModule.watchAllWithdrawals(gh<_i571.WalletRepository>()),
    );
    gh.lazySingleton<_i894.ProfileRepository>(
      () => _i652.FirestoreProfileRepositoryImpl(gh<_i974.FirebaseFirestore>()),
    );
    gh.lazySingleton<_i1028.EarningsRepository>(
      () => _i619.FirestoreEarningsRepositoryImpl(
        gh<_i799.FirestoreEarningsDataSource>(),
      ),
    );
    gh.lazySingleton<_i569.NotificationService>(
      () => _i961.FirebaseNotificationServiceImpl(
        gh<_i317.FirebaseNotificationDataSource>(),
      ),
    );
    gh.lazySingleton<_i462.WatchEventAttendance>(
      () =>
          useCaseModule.watchEventAttendance(gh<_i477.AttendanceRepository>()),
    );
    gh.factory<_i30.StudentProfileCubit>(
      () => _i30.StudentProfileCubit(gh<_i894.ProfileRepository>()),
    );
    gh.lazySingleton<_i702.DecideApplication>(
      () => useCaseModule.decideApplication(
        gh<_i873.ApplicationRepository>(),
        gh<_i199.EventRepository>(),
      ),
    );
    gh.lazySingleton<_i326.EarningsService>(
      () => _i89.FirestoreEarningsService(gh<_i1028.EarningsRepository>()),
    );
    gh.lazySingleton<_i293.CheckIn>(
      () => useCaseModule.checkIn(
        gh<_i477.AttendanceRepository>(),
        gh<_i199.EventRepository>(),
      ),
    );
    gh.lazySingleton<_i25.CheckOut>(
      () => useCaseModule.checkOut(
        gh<_i477.AttendanceRepository>(),
        gh<_i199.EventRepository>(),
      ),
    );
    gh.lazySingleton<_i539.CreateEvent>(
      () => useCaseModule.createEvent(gh<_i199.EventRepository>()),
    );
    gh.lazySingleton<_i920.ChangeEventStatus>(
      () => useCaseModule.changeEventStatus(gh<_i199.EventRepository>()),
    );
    gh.lazySingleton<_i1019.WatchVendorEvents>(
      () => useCaseModule.watchVendorEvents(gh<_i199.EventRepository>()),
    );
    gh.lazySingleton<_i1037.WatchActiveEvents>(
      () => useCaseModule.watchActiveEvents(gh<_i199.EventRepository>()),
    );
    gh.lazySingleton<_i546.GetEvent>(
      () => useCaseModule.getEvent(gh<_i199.EventRepository>()),
    );
    gh.lazySingleton<_i684.SubmitReport>(
      () => useCaseModule.submitReport(gh<_i939.ReportRepository>()),
    );
    gh.lazySingleton<_i517.ListReports>(
      () => useCaseModule.listReports(gh<_i939.ReportRepository>()),
    );
    gh.lazySingleton<_i474.RequestOtp>(
      () => useCaseModule.requestOtp(gh<_i787.AuthRepository>()),
    );
    gh.lazySingleton<_i975.VerifyOtp>(
      () => useCaseModule.verifyOtp(gh<_i787.AuthRepository>()),
    );
    gh.lazySingleton<_i725.WatchSession>(
      () => useCaseModule.watchSession(gh<_i787.AuthRepository>()),
    );
    gh.lazySingleton<_i568.SignOut>(
      () => useCaseModule.signOut(gh<_i787.AuthRepository>()),
    );
    gh.lazySingleton<_i730.GetMetrics>(
      () => useCaseModule.getMetrics(gh<_i219.MetricsService>()),
    );
    gh.factory<_i671.RegistrationBloc>(
      () => _i671.RegistrationBloc.inject(
        profileRepository: gh<_i894.ProfileRepository>(),
        storageRepository: gh<_i50.StorageRepository>(),
      ),
    );
    gh.factory<_i922.WithdrawalReviewCubit>(
      () => _i922.WithdrawalReviewCubit(
        gh<_i575.WatchAllWithdrawals>(),
        gh<_i470.DecideWithdrawal>(),
      ),
    );
    gh.factory<_i797.AuthBloc>(
      () => _i797.AuthBloc(
        gh<_i474.RequestOtp>(),
        gh<_i975.VerifyOtp>(),
        gh<_i725.WatchSession>(),
        gh<_i568.SignOut>(),
      ),
    );
    gh.lazySingleton<_i794.GenerateAttendanceCode>(
      () => useCaseModule.generateAttendanceCode(gh<_i199.EventRepository>()),
    );
    gh.lazySingleton<_i719.WatchEventApplications>(
      () => useCaseModule.watchEventApplications(
        gh<_i873.ApplicationRepository>(),
      ),
    );
    gh.lazySingleton<_i566.WatchStudentApplications>(
      () => useCaseModule.watchStudentApplications(
        gh<_i873.ApplicationRepository>(),
      ),
    );
    gh.factory<_i55.AdminBloc>(
      () => _i55.AdminBloc(
        gh<_i864.ApproveVendor>(),
        gh<_i135.RejectVendor>(),
        gh<_i24.ListStudents>(),
        gh<_i792.ListVendors>(),
        gh<_i481.ListEvents>(),
        gh<_i730.GetMetrics>(),
      ),
    );
    gh.lazySingleton<_i803.ApplyToEvent>(
      () => useCaseModule.applyToEvent(
        gh<_i199.EventRepository>(),
        gh<_i873.ApplicationRepository>(),
        gh<_i894.ProfileRepository>(),
      ),
    );
    gh.factory<_i558.WalletCubit>(
      () => _i558.WalletCubit(
        gh<_i477.AttendanceRepository>(),
        gh<_i566.WatchStudentApplications>(),
        gh<_i390.WatchStudentWithdrawals>(),
        gh<_i418.RequestWithdrawal>(),
      ),
    );
    gh.lazySingleton<_i176.GetEarnings>(
      () => useCaseModule.getEarnings(gh<_i1028.EarningsRepository>()),
    );
    gh.factory<_i652.ReportBloc>(
      () => _i652.ReportBloc(gh<_i684.SubmitReport>()),
    );
    gh.factory<_i700.AttendanceBloc>(
      () => _i700.AttendanceBloc(
        gh<_i293.CheckIn>(),
        gh<_i25.CheckOut>(),
        gh<_i477.AttendanceRepository>(),
        gh<_i232.DeviceLocationService>(),
      ),
    );
    gh.factory<_i142.EarningsBloc>(
      () => _i142.EarningsBloc(gh<_i176.GetEarnings>()),
    );
    gh.factory<_i653.EventManagementBloc>(
      () => _i653.EventManagementBloc(
        gh<_i539.CreateEvent>(),
        gh<_i920.ChangeEventStatus>(),
        gh<_i1019.WatchVendorEvents>(),
      ),
    );
    gh.factory<_i726.StudentApplicationsCubit>(
      () =>
          _i726.StudentApplicationsCubit(gh<_i566.WatchStudentApplications>()),
    );
    gh.factory<_i785.EventDiscoveryBloc>(
      () => _i785.EventDiscoveryBloc(
        gh<_i1037.WatchActiveEvents>(),
        gh<_i776.SearchActiveEvents>(),
        gh<_i546.GetEvent>(),
      ),
    );
    gh.factory<_i876.ApplicationBloc>(
      () => _i876.ApplicationBloc(
        applyToEvent: gh<_i803.ApplyToEvent>(),
        decideApplication: gh<_i702.DecideApplication>(),
        watchEventApplications: gh<_i719.WatchEventApplications>(),
        generateAttendanceCode: gh<_i794.GenerateAttendanceCode>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}

class _$UseCaseModule extends _i1054.UseCaseModule {}
