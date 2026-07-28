import '../../../auth/domain/entities/user_role.dart';

/// A single navigation destination in the application.
///
/// Each destination is owned by exactly one [UserRole] (its [owner]) or by no
/// role at all (a shared, non-role destination such as [authentication] or
/// [noRole], whose [owner] is `null`). This ownership is the backbone of
/// role-based navigation (R3): the set of destinations a role may see is
/// exactly the set of destinations whose [owner] equals that role, and every
/// other role's destinations are hidden (R3.1).
///
/// This is a pure domain value: it carries no backend or Flutter types and is
/// safe to reason about and property-test in isolation.
enum Destination {
  /// The authentication screen shown to unauthenticated users (R3.4).
  ///
  /// Not associated with any role, so it is never part of a role's visible
  /// navigation set.
  authentication(owner: null, isHome: false),

  /// The "no valid role assigned" screen shown when an authenticated user has
  /// no role or an unrecognized role value (R3.3).
  ///
  /// Not associated with any role; no role-specific destinations accompany it.
  noRole(owner: null, isHome: false),

  // --- Student destinations (R4, R8, R10, R11, R12) ---

  /// The student's home dashboard and default landing destination (R4).
  studentDashboard(owner: UserRole.student, isHome: true),

  /// Event discovery and search for students (R8).
  studentDiscovery(owner: UserRole.student, isHome: false),

  /// Check-in / check-out and attendance history for students (R10).
  studentAttendance(owner: UserRole.student, isHome: false),

  /// Estimated-earnings view for students (R11).
  studentEarnings(owner: UserRole.student, isHome: false),

  /// The student's profile view (R4.6).
  studentProfile(owner: UserRole.student, isHome: false),

  /// Report submission for students (R12.1).
  studentReports(owner: UserRole.student, isHome: false),

  // --- Vendor destinations (R5, R7, R12) ---

  /// The vendor's manage-events home and default landing destination (R5.2).
  vendorEvents(owner: UserRole.vendor, isHome: true),

  /// Applicant review for a vendor's events (R5.3).
  vendorApplicants(owner: UserRole.vendor, isHome: false),

  /// Attendance code generation and attendance view for a vendor's events
  /// (R5.6, R5.7).
  vendorAttendance(owner: UserRole.vendor, isHome: false),

  /// The vendor's profile view.
  vendorProfile(owner: UserRole.vendor, isHome: false),

  /// Report submission for vendors (R12.2).
  vendorReports(owner: UserRole.vendor, isHome: false),

  // --- Staff destinations (vendor team) ---

  /// The staff member's home: the scoped portal over their parent vendor's
  /// events, gated to managing applicants and/or attendance by their role.
  staffHome(owner: UserRole.staff, isHome: true),

  // --- Admin destinations (R6, R12) ---

  /// The admin's dashboard and default landing destination, including metrics
  /// (R6.7).
  adminDashboard(owner: UserRole.admin, isHome: true),

  /// Vendor approval queue for admins (R6.1, R6.2).
  adminVendorApprovals(owner: UserRole.admin, isHome: false),

  /// The registered-students list for admins (R6.4).
  adminStudents(owner: UserRole.admin, isHome: false),

  /// The registered-vendors list for admins (R6.5).
  adminVendors(owner: UserRole.admin, isHome: false),

  /// The all-events list for admins (R6.6).
  adminEvents(owner: UserRole.admin, isHome: false),

  /// The submitted-reports review for admins (R6.8, R12.6).
  adminReports(owner: UserRole.admin, isHome: false);

  const Destination({required this.owner, required this.isHome});

  /// The role that owns this destination, or `null` for a shared, non-role
  /// destination (e.g. [authentication], [noRole]).
  final UserRole? owner;

  /// Whether this destination is the default ("home") landing destination for
  /// its [owner] role. Exactly one destination per role is the home.
  final bool isHome;

  /// Whether this destination belongs to a specific role.
  ///
  /// Shared destinations such as [authentication] and [noRole] return `false`.
  bool get isRoleDestination => owner != null;
}

/// Role-based grouping and lookup helpers over [Destination].
extension RoleDestinations on UserRole {
  /// The destinations visible to this role: exactly the destinations whose
  /// [Destination.owner] equals this role (R3.1).
  List<Destination> get destinations => Destination.values
      .where((Destination d) => d.owner == this)
      .toList(growable: false);

  /// The default ("home") destination for this role (R3.1, R3.2).
  ///
  /// Every role defines exactly one home destination, so this always resolves
  /// to a single value.
  Destination get defaultDestination => Destination.values
      .firstWhere((Destination d) => d.owner == this && d.isHome);
}

/// The complete role → destinations map.
///
/// For each [UserRole] this maps to exactly that role's destinations and, by
/// construction, excludes every other role's destinations (R3.1, R3.3). Use
/// this as the single source of truth for which destinations a role may see.
final Map<UserRole, List<Destination>> roleDestinations =
    Map<UserRole, List<Destination>>.unmodifiable(<UserRole, List<Destination>>{
  for (final UserRole role in UserRole.values) role: role.destinations,
});
