import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/staff_member.dart';
import '../../domain/entities/staff_role.dart';

/// Firestore wire/document shape for a `staff/{staffId}` document.
///
/// The only place that knows Firebase types (`Timestamp`) for staff; conversion
/// to/from the pure [StaffMember] entity lives here.
class StaffDto {
  const StaffDto({
    required this.staffId,
    required this.vendorId,
    required this.name,
    required this.phone,
    required this.role,
    required this.active,
    required this.createdAt,
    this.uid,
  });

  final String staffId;
  final String vendorId;
  final String name;
  final String phone;

  /// The role wire-name (`Manager` | `ApplicantReviewer` | `AttendanceStaff`).
  final String role;
  final String? uid;
  final bool active;
  final Timestamp createdAt;

  factory StaffDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return StaffDto(
      staffId: (data['staffId'] as String?) ?? doc.id,
      vendorId: data['vendorId'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String,
      role: data['role'] as String,
      uid: data['uid'] as String?,
      active: (data['active'] as bool?) ?? false,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  factory StaffDto.fromEntity(StaffMember staff) => StaffDto(
        staffId: staff.staffId,
        vendorId: staff.vendorId,
        name: staff.name,
        phone: staff.phone,
        role: staff.role.wireName,
        uid: staff.uid,
        active: staff.active,
        createdAt: Timestamp.fromDate(staff.createdAt),
      );

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'staffId': staffId,
        'vendorId': vendorId,
        'name': name,
        'phone': phone,
        'role': role,
        if (uid != null) 'uid': uid,
        'active': active,
        'createdAt': createdAt,
      };

  /// Converts to the pure domain entity, defaulting an unknown stored role to
  /// [StaffRole.attendanceStaff] (least privilege) rather than throwing.
  StaffMember toEntity() => StaffMember(
        staffId: staffId,
        vendorId: vendorId,
        name: name,
        phone: phone,
        role: StaffRoleX.tryParse(role) ?? StaffRole.attendanceStaff,
        uid: uid,
        active: active,
        createdAt: createdAt.toDate(),
      );
}
