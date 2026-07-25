import 'package:eventxindia/core/value_objects/application_status.dart';
import 'package:eventxindia/features/applications/domain/entities/application.dart';
import 'package:eventxindia/features/applications/domain/usecases/watch_student_applications.dart';
import 'package:eventxindia/features/attendance/domain/entities/attendance_record.dart';
import 'package:eventxindia/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:eventxindia/features/wallet/domain/entities/withdrawal_request.dart';
import 'package:eventxindia/features/wallet/domain/usecases/request_withdrawal.dart';
import 'package:eventxindia/features/wallet/domain/usecases/watch_student_withdrawals.dart';
import 'package:eventxindia/features/wallet/presentation/bloc/wallet_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttendanceRepository extends Mock implements AttendanceRepository {}

class _MockWatchStudentApplications extends Mock
    implements WatchStudentApplications {}

class _MockWatchStudentWithdrawals extends Mock
    implements WatchStudentWithdrawals {}

class _MockRequestWithdrawal extends Mock implements RequestWithdrawal {}

AttendanceRecord _completed(String eventId, String studentId) {
  final DateTime t = DateTime(2026, 6, 1, 9);
  return AttendanceRecord(
    attendanceId: '${eventId}_$studentId',
    eventId: eventId,
    studentId: studentId,
    checkInTime: t,
    checkOutTime: t.add(const Duration(hours: 4)),
    createdAt: t,
    updatedAt: t,
  );
}

Application _application(
  String eventId,
  String studentId, {
  required int payMinor,
  int? commissionPercent,
}) {
  final DateTime t = DateTime(2026, 5, 1);
  return Application(
    applicationId: '${eventId}_$studentId',
    eventId: eventId,
    studentId: studentId,
    status: ApplicationStatus.approved,
    createdAt: t,
    updatedAt: t,
    eventTitle: 'Event $eventId',
    eventPayMinorUnits: payMinor,
    eventCommissionPercent: commissionPercent,
  );
}

void main() {
  late _MockAttendanceRepository attendance;
  late _MockWatchStudentApplications applications;
  late _MockWatchStudentWithdrawals withdrawals;
  late _MockRequestWithdrawal requestWithdrawal;

  setUp(() {
    attendance = _MockAttendanceRepository();
    applications = _MockWatchStudentApplications();
    withdrawals = _MockWatchStudentWithdrawals();
    requestWithdrawal = _MockRequestWithdrawal();
  });

  WalletCubit build() => WalletCubit(
        attendance,
        applications,
        withdrawals,
        requestWithdrawal,
      );

  test('credits the student the NET pay after the snapshotted commission',
      () async {
    // Vendor pays ₹100 (10000 paise) per slot; the event was snapshotted at a
    // 10% commission, so the student takes home ₹90 for the completed event.
    when(() => attendance.watchByStudent('s1')).thenAnswer(
      (_) => Stream<List<AttendanceRecord>>.value(
        <AttendanceRecord>[_completed('e1', 's1')],
      ),
    );
    when(() => applications(studentId: 's1')).thenAnswer(
      (_) => Stream<List<Application>>.value(
        <Application>[
          _application('e1', 's1', payMinor: 10000, commissionPercent: 10),
        ],
      ),
    );
    when(() => withdrawals('s1')).thenAnswer(
      (_) => Stream<List<WithdrawalRequest>>.value(const <WithdrawalRequest>[]),
    );

    final WalletCubit cubit = build();
    cubit.watch('s1');

    final WalletState state =
        await cubit.stream.firstWhere((WalletState s) => s is WalletLoaded);
    final WalletLoaded loaded = state as WalletLoaded;
    expect(loaded.wallet.credited.minorUnits, 9000); // ₹90 net
    expect(loaded.wallet.creditsPerEvent['e1']!.minorUnits, 9000);
    expect(loaded.wallet.available.minorUnits, 9000);

    await cubit.close();
  });

  test('a missing commission snapshot means no deduction (legacy records)',
      () async {
    when(() => attendance.watchByStudent('s1')).thenAnswer(
      (_) => Stream<List<AttendanceRecord>>.value(
        <AttendanceRecord>[_completed('e1', 's1')],
      ),
    );
    when(() => applications(studentId: 's1')).thenAnswer(
      (_) => Stream<List<Application>>.value(
        <Application>[
          _application('e1', 's1', payMinor: 10000), // no commission snapshot
        ],
      ),
    );
    when(() => withdrawals('s1')).thenAnswer(
      (_) => Stream<List<WithdrawalRequest>>.value(const <WithdrawalRequest>[]),
    );

    final WalletCubit cubit = build();
    cubit.watch('s1');

    final WalletState state =
        await cubit.stream.firstWhere((WalletState s) => s is WalletLoaded);
    expect((state as WalletLoaded).wallet.credited.minorUnits, 10000);

    await cubit.close();
  });
}
