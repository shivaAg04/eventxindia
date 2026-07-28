/// A predefined role a vendor may assign to a staff member, bundling a fixed
/// set of permissions. Staff act on the owning vendor's events with only the
/// access their role grants.
///
/// The two capabilities a vendor can delegate are **managing applicants**
/// (approve/reject students) and **managing attendance** (generate codes, mark
/// check-in/out). The three roles are the useful combinations of those two.
enum StaffRole {
  /// Full staff access: manage applicants AND attendance.
  manager,

  /// Manage applicants only (approve/reject students).
  applicantReviewer,

  /// Manage attendance only (codes, check-in/out).
  attendanceStaff;

  /// Whether this role may approve/reject applicants.
  bool get canManageApplicants =>
      this == StaffRole.manager || this == StaffRole.applicantReviewer;

  /// Whether this role may manage attendance (codes, check-in/out).
  bool get canManageAttendance =>
      this == StaffRole.manager || this == StaffRole.attendanceStaff;

  /// A short, human-readable label for the role.
  String get label {
    switch (this) {
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.applicantReviewer:
        return 'Applicant Reviewer';
      case StaffRole.attendanceStaff:
        return 'Attendance Staff';
    }
  }

  /// The canonical wire/storage representation.
  String get wireName {
    switch (this) {
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.applicantReviewer:
        return 'ApplicantReviewer';
      case StaffRole.attendanceStaff:
        return 'AttendanceStaff';
    }
  }
}

/// Parsing helpers that enforce validity for [StaffRole] at the boundary.
extension StaffRoleX on StaffRole {
  /// Parses a wire/storage string into a [StaffRole], returning `null` for an
  /// unknown value rather than throwing.
  static StaffRole? tryParse(String value) {
    for (final StaffRole role in StaffRole.values) {
      if (role.wireName == value) {
        return role;
      }
    }
    return null;
  }

  /// Parses a wire/storage string into a [StaffRole], throwing on unknown input.
  static StaffRole parse(String value) {
    final StaffRole? role = tryParse(value);
    if (role == null) {
      throw ArgumentError.value(value, 'value', 'Unknown StaffRole');
    }
    return role;
  }
}
