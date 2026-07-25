import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/money.dart';
import '../../../applications/domain/entities/application.dart';
import '../../../applications/domain/usecases/watch_student_applications.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/domain/repositories/attendance_repository.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/usecases/request_withdrawal.dart';
import '../../domain/usecases/watch_student_withdrawals.dart';

part 'wallet_state.dart';

/// Drives the student's wallet screen (R11 wallet).
///
/// The wallet credit is computed **client-side** (bookkeeping only — no trusted
/// backend accrual): a student earns an event's pay once their attendance for
/// it is *completed* (both check-in and check-out recorded). It composes three
/// live streams —
///  * attendance records ([AttendanceRepository], which events are completed),
///  * applications ([WatchStudentApplications], carrying each event's pay
///    snapshot in [Application.eventPayMinorUnits]),
///  * withdrawal requests ([WatchStudentWithdrawals], the "money out") —
/// into a single [Wallet] with derived balances, and exposes [request] to
/// create a withdrawal (validated against the available balance).
@injectable
class WalletCubit extends Cubit<WalletState> {
  WalletCubit(
    this._attendanceRepository,
    this._watchStudentApplications,
    this._watchWithdrawals,
    this._requestWithdrawal,
  ) : super(const WalletLoading());

  final AttendanceRepository _attendanceRepository;
  final WatchStudentApplications _watchStudentApplications;
  final WatchStudentWithdrawals _watchWithdrawals;
  final RequestWithdrawal _requestWithdrawal;

  String? _studentId;
  List<AttendanceRecord> _attendance = const <AttendanceRecord>[];
  List<Application> _applications = const <Application>[];
  List<WithdrawalRequest> _withdrawals = const <WithdrawalRequest>[];
  bool _hasAttendance = false;
  bool _hasApplications = false;
  bool _hasWithdrawals = false;

  StreamSubscription<List<AttendanceRecord>>? _attendanceSub;
  StreamSubscription<List<Application>>? _applicationsSub;
  StreamSubscription<List<WithdrawalRequest>>? _withdrawalsSub;

  /// Starts watching [studentId]'s attendance, applications and withdrawals.
  void watch(String studentId) {
    _studentId = studentId;
    emit(const WalletLoading());
    _attendanceSub?.cancel();
    _applicationsSub?.cancel();
    _withdrawalsSub?.cancel();

    _attendanceSub = _attendanceRepository.watchByStudent(studentId).listen(
      (List<AttendanceRecord> records) {
        _attendance = records;
        _hasAttendance = true;
        _emit();
      },
      onError: (Object error, StackTrace _) =>
          emit(WalletFailure(error.toString())),
    );

    _applicationsSub =
        _watchStudentApplications(studentId: studentId).listen(
      (List<Application> applications) {
        _applications = applications;
        _hasApplications = true;
        _emit();
      },
      onError: (Object error, StackTrace _) =>
          emit(WalletFailure(error.toString())),
    );

    _withdrawalsSub = _watchWithdrawals(studentId).listen(
      (List<WithdrawalRequest> withdrawals) {
        _withdrawals = withdrawals;
        _hasWithdrawals = true;
        _emit();
      },
      onError: (Object error, StackTrace _) =>
          emit(WalletFailure(error.toString())),
    );
  }

  void _emit() {
    // Wait for the first emission of all three streams before showing the
    // wallet, so balances are computed from a complete picture.
    if (!_hasAttendance ||
        !_hasApplications ||
        !_hasWithdrawals ||
        _studentId == null) {
      return;
    }

    // The pay and title for each event, from the application's snapshot.
    final Map<String, Money> payByEvent = <String, Money>{};
    final Map<String, String> titleByEvent = <String, String>{};
    for (final Application a in _applications) {
      final int? pay = a.eventPayMinorUnits;
      if (pay != null) {
        payByEvent[a.eventId] =
            Money.fromMinorUnits(pay, requirePayPerHeadRange: false);
      }
      final String? title = a.eventTitle;
      if (title != null && title.isNotEmpty) {
        titleByEvent[a.eventId] = title;
      }
    }

    // Credit an event once its attendance is completed (checked in AND out).
    final Map<String, Money> creditsPerEvent = <String, Money>{};
    final Map<String, String> eventNames = <String, String>{};
    for (final AttendanceRecord r in _attendance) {
      if (r.checkInTime != null && r.checkOutTime != null) {
        final Money? pay = payByEvent[r.eventId];
        if (pay != null) {
          creditsPerEvent[r.eventId] = pay;
          final String? title = titleByEvent[r.eventId];
          if (title != null) {
            eventNames[r.eventId] = title;
          }
        }
      }
    }

    Money credited = Money.zero;
    for (final Money m in creditsPerEvent.values) {
      credited = credited + m;
    }

    emit(
      WalletLoaded(
        Wallet(
          studentId: _studentId!,
          credited: credited,
          creditsPerEvent: creditsPerEvent,
          withdrawals: _withdrawals,
          eventNames: eventNames,
        ),
      ),
    );
  }

  /// Requests a withdrawal of [amount], bounded by the current available
  /// balance. Returns the result so the screen can confirm or report the error;
  /// on success the withdrawal stream updates the balances.
  Future<Result<WithdrawalRequest, Failure>> request(Money amount) {
    final WalletState current = state;
    final Money available =
        current is WalletLoaded ? current.wallet.available : Money.zero;
    return _requestWithdrawal(
      studentId: _studentId!,
      amount: amount,
      available: available,
    );
  }

  @override
  Future<void> close() async {
    await _attendanceSub?.cancel();
    await _applicationsSub?.cancel();
    await _withdrawalsSub?.cancel();
    return super.close();
  }
}
