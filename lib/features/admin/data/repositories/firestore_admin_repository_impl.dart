import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/approval_status.dart';
import '../../../events/domain/entities/event.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../../reports/domain/entities/report.dart';
import '../../domain/approval_transition.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/firestore_admin_data_source.dart';
import '../mappers/admin_document_mappers.dart';

/// Firebase-backed implementation of [AdminRepository] (R6).
///
/// Reads the four admin monitoring lists (`students`, `vendors`, `events`,
/// `reports`) as live streams (R6.4–R6.6, R6.8), performs the vendor approval
/// transition as a trusted admin write guarded by the pure Pending-only rule
/// (R6.1–R6.3), and registers a user's FCM device token for push delivery
/// (R13.7, R14.5).
///
/// All Firebase types are confined to the injected [FirestoreAdminDataSource]
/// and the [AdminDocumentMappers]; this class speaks only domain entities and
/// `Result<T, Failure>`. Writes go through the data layer [withRetry] policy so
/// a transient failure is retried and a total failure surfaces a
/// [PersistenceFailure] with no partial commit (R14.6).
@LazySingleton(as: AdminRepository)
class FirestoreAdminRepositoryImpl implements AdminRepository {
  const FirestoreAdminRepositoryImpl(this._dataSource);

  final FirestoreAdminDataSource _dataSource;

  @override
  Future<Result<Vendor, Failure>> approveVendor(String vendorId) {
    return _transitionVendor(vendorId, ApprovalDecision.approve);
  }

  @override
  Future<Result<Vendor, Failure>> rejectVendor(String vendorId) {
    return _transitionVendor(vendorId, ApprovalDecision.reject);
  }

  /// Reads the vendor, applies the pure Pending-only guard, and writes the new
  /// approval status under the retry policy, returning the updated [Vendor]
  /// (R6.1–R6.3, R14.6).
  Future<Result<Vendor, Failure>> _transitionVendor(
    String vendorId,
    ApprovalDecision decision,
  ) async {
    final Vendor current;
    try {
      final doc = await _dataSource.getVendor(vendorId);
      if (!doc.exists) {
        return const Result<Vendor, Failure>.err(
          NotFoundFailure(message: 'Vendor not found.'),
        );
      }
      current = AdminDocumentMappers.vendorFromDoc(doc);
    } catch (_) {
      return const Result<Vendor, Failure>.err(PersistenceFailure());
    }

    final Result<ApprovalStatus, Failure> transition =
        resolveApprovalTransition(current.approvalStatus, decision);

    return transition.fold(
      (nextStatus) async {
        final DateTime updatedAt = DateTime.now();
        final Result<Unit, Failure> writeResult = await withRetry<Unit>(
          kDefaultMaxWriteAttempts,
          () async {
            await _dataSource.setVendorApprovalStatus(
              vendorId,
              nextStatus.wireName,
              updatedAt,
            );
            return unit;
          },
        );

        return writeResult.map(
          (_) => current.copyWith(
            approvalStatus: nextStatus,
            updatedAt: updatedAt,
          ),
        );
      },
      (failure) async => Result<Vendor, Failure>.err(failure),
    );
  }

  @override
  Stream<List<Student>> listStudents() {
    return _dataSource.streamStudents().map(
          (docs) => docs.map(AdminDocumentMappers.studentFromDoc).toList(),
        );
  }

  @override
  Stream<List<Vendor>> listVendors() {
    return _dataSource.streamVendors().map(
          (docs) => docs.map(AdminDocumentMappers.vendorFromDoc).toList(),
        );
  }

  @override
  Stream<List<Event>> listEvents() {
    return _dataSource.streamEvents().map(
          (docs) => docs.map(AdminDocumentMappers.eventFromDoc).toList(),
        );
  }

  @override
  Stream<List<Report>> listReports() {
    return _dataSource.streamReports().map(
          (docs) => docs.map(AdminDocumentMappers.reportFromDoc).toList(),
        );
  }

  @override
  Future<Result<Unit, Failure>> registerDeviceToken(
    String uid,
    String token,
  ) {
    return withRetry<Unit>(
      kDefaultMaxWriteAttempts,
      () async {
        await _dataSource.addDeviceToken(uid, token);
        return unit;
      },
    );
  }
}
