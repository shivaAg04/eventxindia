import 'dart:math';

import 'package:injectable/injectable.dart';

import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/domain/services/metrics_service.dart';
import '../../features/admin/domain/usecases/approve_vendor.dart';
import '../../features/admin/domain/usecases/get_metrics.dart';
import '../../features/admin/domain/usecases/list_events.dart';
import '../../features/admin/domain/usecases/list_reports.dart' as admin;
import '../../features/admin/domain/usecases/list_students.dart';
import '../../features/admin/domain/usecases/list_vendors.dart';
import '../../features/admin/domain/usecases/reject_vendor.dart';
import '../../features/applications/domain/repositories/application_repository.dart';
import '../../features/applications/domain/usecases/apply_to_event.dart';
import '../../features/applications/domain/usecases/decide_application.dart';
import '../../features/applications/domain/usecases/watch_event_applications.dart';
import '../../features/applications/domain/usecases/watch_student_applications.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/domain/usecases/check_in.dart';
import '../../features/attendance/domain/usecases/check_out.dart';
import '../../features/attendance/domain/usecases/generate_attendance_code.dart';
import '../../features/attendance/domain/usecases/watch_event_attendance.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/request_otp.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/domain/usecases/watch_session.dart';
import '../../features/events/domain/repositories/event_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/events/domain/usecases/change_event_status.dart';
import '../../features/events/domain/usecases/create_event.dart';
import '../../features/events/domain/usecases/get_event.dart';
import '../../features/events/domain/usecases/search_active_events.dart';
import '../../features/events/domain/usecases/watch_active_events.dart';
import '../../features/events/domain/usecases/watch_vendor_events.dart';
import '../../features/navigation/domain/usecases/authorize.dart';
import '../../features/navigation/domain/usecases/resolve_start_destination.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reports/domain/usecases/list_reports.dart';
import '../../features/reports/domain/usecases/submit_report.dart';
import '../../features/earnings/domain/repositories/earnings_repository.dart';
import '../../features/earnings/domain/usecases/get_earnings.dart';

/// Composition-root bindings for the domain use cases.
///
/// Use cases are pure domain classes and therefore carry **no** `injectable`
/// annotations of their own — keeping the domain layer free of any framework
/// dependency. Instead, the composition root constructs each one here from its
/// injected repository/service interface. The pure function seams — the
/// `DateTime` clock and the attendance-code generator — are supplied here
/// directly (production defaults), so they never need to be registered as
/// injectable function types. `injectable` resolves every class parameter from
/// the container, so adding a use case to a BLoC is a one-line addition here.
///
/// All bindings are lazy singletons: use cases are stateless orchestrators (or,
/// for `VerifyOtp`, keyed per-phone), so a single shared instance per use case
/// is sufficient and avoids rebuilding them for every BLoC construction.
@module
abstract class UseCaseModule {
  // --- Auth (R1, R2, R3) ---------------------------------------------------

  @lazySingleton
  RequestOtp requestOtp(AuthRepository repository) => RequestOtp(repository);

  @lazySingleton
  VerifyOtp verifyOtp(AuthRepository repository) => VerifyOtp(repository);

  @lazySingleton
  WatchSession watchSession(AuthRepository repository) =>
      WatchSession(repository);

  @lazySingleton
  SignOut signOut(AuthRepository repository) => SignOut(repository);

  // Profile registration no longer has use cases: RegistrationBloc validates
  // and persists through ProfileRepository / StorageRepository directly
  // (R1, R2, R14), mirroring how StudentProfileCubit reads.

  // --- Events: management & discovery (R5, R7, R8) -------------------------

  @lazySingleton
  CreateEvent createEvent(EventRepository repository) =>
      CreateEvent(repository: repository);

  @lazySingleton
  ChangeEventStatus changeEventStatus(EventRepository repository) =>
      ChangeEventStatus(repository: repository);

  @lazySingleton
  WatchVendorEvents watchVendorEvents(EventRepository repository) =>
      WatchVendorEvents(repository: repository);

  @lazySingleton
  WatchActiveEvents watchActiveEvents(EventRepository repository) =>
      WatchActiveEvents(repository: repository);

  @lazySingleton
  SearchActiveEvents searchActiveEvents() => const SearchActiveEvents();

  @lazySingleton
  GetEvent getEvent(EventRepository repository) =>
      GetEvent(repository: repository);

  // --- Applications (R5, R8, R9) -------------------------------------------

  @lazySingleton
  ApplyToEvent applyToEvent(
    EventRepository eventRepository,
    ApplicationRepository applicationRepository,
    ProfileRepository profileRepository,
  ) =>
      ApplyToEvent(
        eventRepository: eventRepository,
        applicationRepository: applicationRepository,
        profileRepository: profileRepository,
        now: DateTime.now,
      );

  @lazySingleton
  DecideApplication decideApplication(
    ApplicationRepository applicationRepository,
    EventRepository eventRepository,
  ) =>
      DecideApplication(
        applicationRepository: applicationRepository,
        eventRepository: eventRepository,
        now: DateTime.now,
      );

  @lazySingleton
  WatchEventApplications watchEventApplications(
    ApplicationRepository applicationRepository,
  ) =>
      WatchEventApplications(applicationRepository: applicationRepository);

  @lazySingleton
  WatchStudentApplications watchStudentApplications(
    ApplicationRepository applicationRepository,
  ) =>
      WatchStudentApplications(applicationRepository: applicationRepository);

  // --- Attendance (R5, R10) ------------------------------------------------

  @lazySingleton
  CheckIn checkIn(
    AttendanceRepository attendanceRepository,
    EventRepository eventRepository,
  ) =>
      CheckIn(
        attendanceRepository: attendanceRepository,
        eventRepository: eventRepository,
        now: DateTime.now,
      );

  @lazySingleton
  CheckOut checkOut(
    AttendanceRepository attendanceRepository,
    EventRepository eventRepository,
  ) =>
      CheckOut(
        attendanceRepository: attendanceRepository,
        eventRepository: eventRepository,
        now: DateTime.now,
      );

  @lazySingleton
  GenerateAttendanceCode generateAttendanceCode(
    EventRepository eventRepository,
  ) =>
      GenerateAttendanceCode(
        eventRepository: eventRepository,
        generateCode: _generateAttendanceCode,
      );

  @lazySingleton
  WatchEventAttendance watchEventAttendance(
    AttendanceRepository attendanceRepository,
  ) =>
      WatchEventAttendance(repository: attendanceRepository);

  // --- Earnings (R11) ------------------------------------------------------

  @lazySingleton
  GetEarnings getEarnings(EarningsRepository earningsRepository) =>
      GetEarnings(earningsRepository: earningsRepository);

  // --- Reports (R12) -------------------------------------------------------

  @lazySingleton
  SubmitReport submitReport(
    ReportRepository repository,
  ) =>
      SubmitReport(repository: repository, now: DateTime.now);

  @lazySingleton
  ListReports listReports(ReportRepository repository) =>
      ListReports(repository: repository);

  // --- Admin (R6) ----------------------------------------------------------

  @lazySingleton
  ApproveVendor approveVendor(AdminRepository repository) =>
      ApproveVendor(repository);

  @lazySingleton
  RejectVendor rejectVendor(AdminRepository repository) =>
      RejectVendor(repository);

  @lazySingleton
  ListStudents listStudents(AdminRepository repository) =>
      ListStudents(repository);

  @lazySingleton
  ListVendors listVendors(AdminRepository repository) =>
      ListVendors(repository);

  @lazySingleton
  ListEvents listEvents(AdminRepository repository) => ListEvents(repository);

  @lazySingleton
  admin.ListReports adminListReports(AdminRepository repository) =>
      admin.ListReports(repository);

  @lazySingleton
  GetMetrics getMetrics(MetricsService service) => GetMetrics(service);

  // --- Navigation guards (R3) ----------------------------------------------

  @lazySingleton
  Authorize authorize() => const Authorize();

  @lazySingleton
  ResolveStartDestination resolveStartDestination() =>
      const ResolveStartDestination();
}

/// A cryptographically-seeded 6-digit attendance code (000000–999999).
///
/// Used as the production [GenerateAttendanceCode] generator seam. The value is
/// opaque to the domain, which treats it as an arbitrary code string (R5.6).
String _generateAttendanceCode() {
  final Random random = Random.secure();
  final int value = random.nextInt(1000000);
  return value.toString().padLeft(6, '0');
}
