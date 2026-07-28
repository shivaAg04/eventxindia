import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/staff_member.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/firestore_staff_data_source.dart';
import '../dtos/staff_dto.dart';

/// Firestore implementation of [StaffRepository].
///
/// Translates pure [StaffMember] values to/from Firestore documents via
/// [StaffDto] and routes writes through the [withRetry] policy. A duplicate
/// phone (the create transaction finds an existing composite id) maps to a
/// [StateTransitionFailure].
@LazySingleton(as: StaffRepository)
class FirestoreStaffRepositoryImpl implements StaffRepository {
  const FirestoreStaffRepositoryImpl(this._dataSource);

  final FirestoreStaffDataSource _dataSource;

  @override
  Stream<List<StaffMember>> watchByVendor(String vendorId) {
    return _dataSource.watchByVendor(vendorId).map(
          (List<StaffDto> dtos) =>
              dtos.map((StaffDto d) => d.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<Result<StaffMember, Failure>> add(StaffMember staff) {
    return withRetry<StaffMember>(
      kDefaultMaxWriteAttempts,
      () async {
        final StaffDto stored =
            await _dataSource.create(StaffDto.fromEntity(staff));
        return stored.toEntity();
      },
      onFailure: (Object error, StackTrace _) => error is StateError
          ? const StateTransitionFailure(
              message: 'This phone is already added as staff.',
            )
          : const PersistenceFailure(),
    );
  }

  @override
  Future<Result<Unit, Failure>> remove(String staffId) async {
    final Result<Unit, Failure> result = await withRetry<Unit>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.delete(staffId);
        return unit;
      },
    );
    return result;
  }

  @override
  Future<Result<StaffMember?, Failure>> findByPhone(String phoneE164) async {
    try {
      final StaffDto? dto = await _dataSource.findByPhone(phoneE164);
      return Result<StaffMember?, Failure>.ok(dto?.toEntity());
    } catch (_) {
      return const Result<StaffMember?, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Future<Result<StaffMember?, Failure>> provisionOnLogin({
    required String uid,
    required String phoneE164,
  }) async {
    try {
      final StaffDto? dto =
          await _dataSource.provisionOnLogin(uid: uid, phoneE164: phoneE164);
      return Result<StaffMember?, Failure>.ok(dto?.toEntity());
    } catch (_) {
      return const Result<StaffMember?, Failure>.err(PersistenceFailure());
    }
  }
}
