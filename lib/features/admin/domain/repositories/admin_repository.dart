import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../events/domain/entities/event.dart';
import '../../../profile/domain/entities/student.dart';
import '../../../profile/domain/entities/vendor.dart';
import '../../../reports/domain/entities/report.dart';

/// Abstract data boundary for Admin capabilities (R6).
///
/// This interface lives in the domain layer and is expressed entirely in pure
/// Dart types — no Firebase type ever crosses it. The current backend provides
/// `FirestoreAdminRepositoryImpl`; a future Node.js backend provides
/// `RestAdminRepositoryImpl`. Use cases depend only on this abstraction.
///
/// Responsibilities:
/// - Vendor approval transitions ([approveVendor], [rejectVendor]).
/// - Admin monitoring lists ([listStudents], [listVendors], [listEvents],
///   [listReports]).
/// - Device-token registration for push notifications ([registerDeviceToken]).
abstract class AdminRepository {
  /// Approves the vendor identified by [vendorId], setting its approval status
  /// to `Approved` (R6.1).
  ///
  /// The Pending-only guard is enforced by the use case; an implementation
  /// returns a [StateTransitionFailure] when the backend rejects the
  /// transition for a non-Pending vendor (R6.3) and the updated [Vendor] on
  /// success.
  Future<Result<Vendor, Failure>> approveVendor(String vendorId);

  /// Rejects the vendor identified by [vendorId], setting its approval status
  /// to `Rejected` (R6.2).
  ///
  /// Returns a [StateTransitionFailure] when the vendor is not in a `Pending`
  /// state (R6.3) and the updated [Vendor] on success.
  Future<Result<Vendor, Failure>> rejectVendor(String vendorId);

  /// Streams all registered students for the Admin student list (R6.4).
  ///
  /// Emits an empty list when no students are registered (R6.9).
  Stream<List<Student>> listStudents();

  /// Streams all registered vendors, each with its approval status, for the
  /// Admin vendor list (R6.5).
  ///
  /// Emits an empty list when no vendors are registered (R6.9).
  Stream<List<Vendor>> listVendors();

  /// Streams all events, each with its status, for the Admin event list (R6.6).
  ///
  /// Emits an empty list when no events exist (R6.9).
  Stream<List<Event>> listEvents();

  /// Streams all submitted reports for the Admin reports view (R6.8).
  ///
  /// Emits an empty list when no reports exist (R6.9).
  Stream<List<Report>> listReports();

  /// Registers the FCM [token] as a device token for the user identified by
  /// [uid] so the trusted notification service can deliver to them (R13.7).
  ///
  /// Returns [Unit] on success or a [PersistenceFailure] if the write fails
  /// after the retry policy is exhausted (R14.6).
  Future<Result<Unit, Failure>> registerDeviceToken(String uid, String token);
}
