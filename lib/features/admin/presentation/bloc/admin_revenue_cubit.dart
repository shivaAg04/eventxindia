import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/domain/repositories/attendance_repository.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/revenue_summary.dart';

part 'admin_revenue_state.dart';

/// Drives the admin revenue screen (R6).
///
/// Composes two admin-readable streams — every event ([AdminRepository]) and
/// every attendance record ([AttendanceRepository.watchAll]) — into a single
/// [RevenueSummary] (total revenue from completed events + money earned by all
/// students). The aggregation itself is the pure [computeRevenueSummary].
@injectable
class AdminRevenueCubit extends Cubit<AdminRevenueState> {
  AdminRevenueCubit(this._adminRepository, this._attendanceRepository)
      : super(const RevenueLoading());

  final AdminRepository _adminRepository;
  final AttendanceRepository _attendanceRepository;

  List<Event> _events = const <Event>[];
  List<AttendanceRecord> _attendance = const <AttendanceRecord>[];
  bool _hasEvents = false;
  bool _hasAttendance = false;

  StreamSubscription<List<Event>>? _eventsSub;
  StreamSubscription<List<AttendanceRecord>>? _attendanceSub;

  void watch() {
    emit(const RevenueLoading());
    _eventsSub?.cancel();
    _attendanceSub?.cancel();

    _eventsSub = _adminRepository.listEvents().listen(
      (List<Event> events) {
        _events = events;
        _hasEvents = true;
        _emit();
      },
      onError: (Object e, StackTrace _) => emit(RevenueFailure(e.toString())),
    );

    _attendanceSub = _attendanceRepository.watchAll().listen(
      (List<AttendanceRecord> records) {
        _attendance = records;
        _hasAttendance = true;
        _emit();
      },
      onError: (Object e, StackTrace _) => emit(RevenueFailure(e.toString())),
    );
  }

  void _emit() {
    if (!_hasEvents || !_hasAttendance) return;
    emit(RevenueLoaded(
      computeRevenueSummary(_events, _attendance, DateTime.now()),
    ));
  }

  @override
  Future<void> close() async {
    await _eventsSub?.cancel();
    await _attendanceSub?.cancel();
    return super.close();
  }
}
