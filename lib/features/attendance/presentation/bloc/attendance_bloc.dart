import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/geo_point.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/usecases/check_in.dart';
import '../../domain/usecases/check_out.dart';
import 'device_location_service.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

/// Presentation-layer state machine for a student's attendance flow
/// (R10.1–R10.8).
///
/// [AttendanceBloc] translates UI intent ([AttendanceEvent]s) into calls on the
/// attendance use cases and emits [AttendanceState]s the check-in/check-out and
/// history screens render. Per the architecture's dependency rule it depends
/// *only* on the use cases ([CheckIn], [CheckOut]) and the
/// [DeviceLocationService] seam, all injected via the constructor — never on a
/// repository directly for the actions, nor on any Firebase type.
///
/// Event → state mapping:
/// * [CheckInRequested] → `[LocatingDevice, CheckingIn, CheckedIn]` on success,
///   or `[LocatingDevice, AttendanceFailure(reason)]` when location acquisition
///   fails (R10.4), and `[LocatingDevice, CheckingIn, AttendanceFailure]` when
///   the code, distance, or duplicate-check-in guard rejects it
///   (R10.2, R10.3, R10.5).
/// * [CheckOutRequested] → `[CheckingOut, CheckedOut]` on success, or
///   `[CheckingOut, AttendanceFailure(reason)]` when the code or missing
///   check-in guard rejects it (R10.7, R10.8).
/// * [HistoryWatchStarted] → subscribes to the student's attendance stream and
///   emits [HistoryLoaded] as records change (R4.4).
///
/// The bloc reads the student's history through the [AttendanceRepository]
/// stream; the action paths flow exclusively through the injected use cases.
@injectable
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc(
    this._checkIn,
    this._checkOut,
    this._attendanceRepository,
    this._locationService,
  ) : super(const AttendanceInitial()) {
    on<CheckInRequested>(_onCheckInRequested);
    on<CheckOutRequested>(_onCheckOutRequested);
    on<HistoryWatchStarted>(_onHistoryWatchStarted);
  }

  final CheckIn _checkIn;
  final CheckOut _checkOut;
  final AttendanceRepository _attendanceRepository;
  final DeviceLocationService _locationService;

  Future<void> _onCheckInRequested(
    CheckInRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    // R10.4: acquire the device location (≤30s) before attempting the check-in.
    emit(const LocatingDevice());
    final Result<GeoPoint, Failure> location =
        await _locationService.currentLocation();

    if (location.isErr) {
      emit(AttendanceFailure(location.failureOrNull!));
      return;
    }

    emit(const CheckingIn());
    final Result<AttendanceRecord, Failure> result = await _checkIn(
      studentId: event.studentId,
      eventId: event.eventId,
      startCode: event.startCode,
      deviceLocation: location,
    );

    result.fold(
      (AttendanceRecord record) => emit(CheckedIn(record)),
      (Failure failure) => emit(AttendanceFailure(failure)),
    );
  }

  Future<void> _onCheckOutRequested(
    CheckOutRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(const CheckingOut());
    final Result<AttendanceRecord, Failure> result = await _checkOut(
      studentId: event.studentId,
      eventId: event.eventId,
      endCode: event.endCode,
    );

    result.fold(
      (AttendanceRecord record) => emit(CheckedOut(record)),
      (Failure failure) => emit(AttendanceFailure(failure)),
    );
  }

  Future<void> _onHistoryWatchStarted(
    HistoryWatchStarted event,
    Emitter<AttendanceState> emit,
  ) async {
    await emit.forEach<List<AttendanceRecord>>(
      _attendanceRepository.watchByStudent(event.studentId),
      onData: (List<AttendanceRecord> records) => HistoryLoaded(records),
    );
  }
}
