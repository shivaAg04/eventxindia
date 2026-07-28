import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/staff_member.dart';

/// Gateway for a vendor's staff roster — the domain-owned swap line.
///
/// Use cases depend only on this interface; a backend-specific implementation
/// (today Firestore) lives in the data layer and no backend type crosses this
/// boundary.
abstract class StaffRepository {
  /// Streams the staff members belonging to [vendorId] (newest first).
  Stream<List<StaffMember>> watchByVendor(String vendorId);

  /// Adds [staff]. Returns the stored member, or a [StateTransitionFailure]
  /// when a member with the same phone already exists for the vendor.
  Future<Result<StaffMember, Failure>> add(StaffMember staff);

  /// Removes the staff member identified by [staffId].
  Future<Result<Unit, Failure>> remove(String staffId);

  /// Finds the staff invite for [phoneE164] across all vendors, or `null` when
  /// none exists. Used to resolve an invited staff member to their vendor and
  /// role (e.g. the scoped staff portal reads its context this way).
  Future<Result<StaffMember?, Failure>> findByPhone(String phoneE164);

  /// Links a freshly signed-in staff account: if a staff invite matches
  /// [phoneE164], stamps [uid] onto it (marking it active) and provisions the
  /// user's `users/{uid}` record with `role: 'staff'`, their `vendorId` and
  /// `staffRole` — so role-based routing lands them on the scoped staff portal.
  ///
  /// Returns the linked [StaffMember], or `null` when no invite matches (a
  /// normal, non-staff sign-in). Called during OTP verification before falling
  /// back to registration.
  Future<Result<StaffMember?, Failure>> provisionOnLogin({
    required String uid,
    required String phoneE164,
  });
}
