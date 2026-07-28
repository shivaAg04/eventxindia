import 'package:equatable/equatable.dart';

import 'staff_role.dart';

/// A staff member a vendor has added to act on their events, with a
/// [StaffRole] that scopes what they may do (applicants and/or attendance).
///
/// A staff member is added by the vendor with a [name], [phone] (E.164) and
/// [role] before they have ever signed in — so [uid] is `null` until the
/// invited person logs in with that phone for the first time, at which point
/// their account is linked and [active] becomes true.
///
/// Identified by the composite [staffId] `"{vendorId}_{phone}"`, which doubles
/// as the dedupe key so a vendor cannot add the same phone twice. This is a
/// pure domain entity — plain Dart values only, no backend types.
class StaffMember extends Equatable {
  const StaffMember({
    required this.staffId,
    required this.vendorId,
    required this.name,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.uid,
    this.active = false,
  });

  /// Creates a freshly-invited staff member (no linked account yet).
  factory StaffMember.create({
    required String vendorId,
    required String name,
    required String phone,
    required StaffRole role,
    required DateTime now,
  }) {
    return StaffMember(
      staffId: buildId(vendorId: vendorId, phone: phone),
      vendorId: vendorId,
      name: name,
      phone: phone,
      role: role,
      createdAt: now,
    );
  }

  /// The composite identifier `"{vendorId}_{phone}"` (phone digits only), used
  /// as the document id and the "one staff per phone per vendor" dedupe key.
  final String staffId;

  /// The owning vendor's uid.
  final String vendorId;

  /// The staff member's display name (set by the vendor).
  final String name;

  /// The staff member's phone in E.164 form (e.g. `+919876543210`).
  final String phone;

  /// The role scoping what this staff member may do.
  final StaffRole role;

  /// The linked Firebase Auth uid, or `null` until the invitee first signs in.
  final String? uid;

  /// Whether the invitee has signed in and the account is active.
  final bool active;

  /// When the vendor added this staff member.
  final DateTime createdAt;

  /// Builds the composite staff id from [vendorId] and [phone]. Non-digit
  /// characters in the phone (e.g. a leading `+`) are stripped so the id is a
  /// safe Firestore document key.
  static String buildId({
    required String vendorId,
    required String phone,
  }) {
    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '${vendorId}_$digits';
  }

  /// Returns a copy with the given fields replaced.
  StaffMember copyWith({
    String? name,
    StaffRole? role,
    String? uid,
    bool? active,
  }) {
    return StaffMember(
      staffId: staffId,
      vendorId: vendorId,
      name: name ?? this.name,
      phone: phone,
      role: role ?? this.role,
      uid: uid ?? this.uid,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[staffId, vendorId, name, phone, role, uid, active, createdAt];

  @override
  String toString() => 'StaffMember(staffId: $staffId, name: $name, '
      'role: $role, active: $active)';
}
