import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/firestore_attendance_data_source.dart';
import '../dtos/attendance_dto.dart';

/// Firestore-backed implementation of [AttendanceRepository].
///
/// Stores attendance under the `attendance` collection keyed by the composite
/// id `"{eventId}_{studentId}"` (R10.10) via [FirestoreAttendanceDataSource],
/// translating between the pure domain [AttendanceRecord] and the
/// [AttendanceDto] at the boundary. No Firebase type crosses back into the
/// domain.
///
/// Every write is wrapped in the data-layer write-retry policy with three
/// attempts ([kDefaultMaxWriteAttempts]); on exhaustion the operation returns a
/// [PersistenceFailure] with no partial data committed (R14.6). The `accrued`
/// flag is never written from here — the DTO omits it so it stays owned by the
/// trusted backend earnings service (R11.1, R11.2).
@LazySingleton(as: AttendanceRepository)
class FirestoreAttendanceRepositoryImpl implements AttendanceRepository {
  const FirestoreAttendanceRepositoryImpl(this._dataSource);

  final FirestoreAttendanceDataSource _dataSource;

  @override
  Future<Result<AttendanceRecord, Failure>> checkIn(
    AttendanceRecord record,
  ) async {
    return withRetry<AttendanceRecord>(
      kDefaultMaxWriteAttempts,
      () async {
        final AttendanceDto persisted =
            await _dataSource.createCheckIn(AttendanceDto.fromEntity(record));
        return persisted.toEntity();
      },
    );
  }

  @override
  Future<Result<AttendanceRecord, Failure>> checkOut(
    AttendanceRecord record,
  ) async {
    return withRetry<AttendanceRecord>(
      kDefaultMaxWriteAttempts,
      () async {
        final AttendanceDto persisted =
            await _dataSource.updateCheckOut(AttendanceDto.fromEntity(record));
        return persisted.toEntity();
      },
    );
  }

  @override
  Future<Result<AttendanceRecord, Failure>> getById(
    String attendanceId,
  ) async {
    try {
      final AttendanceDto? dto = await _dataSource.getById(attendanceId);
      if (dto == null) {
        return const Result<AttendanceRecord, Failure>.err(
          NotFoundFailure(message: 'Attendance record not found.'),
        );
      }
      return Result<AttendanceRecord, Failure>.ok(dto.toEntity());
    } catch (_) {
      return const Result<AttendanceRecord, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Stream<List<AttendanceRecord>> watchByStudent(String studentId) {
    return _dataSource.watchByStudent(studentId).map(_toEntities);
  }

  @override
  Stream<List<AttendanceRecord>> watchByEvent(String eventId) {
    return _dataSource.watchByEvent(eventId).map(_toEntities);
  }

  @override
  Stream<List<AttendanceRecord>> watchAll() {
    return _dataSource.watchAll().map(_toEntities);
  }

  List<AttendanceRecord> _toEntities(List<AttendanceDto> dtos) =>
      dtos.map((AttendanceDto dto) => dto.toEntity()).toList(growable: false);
}
