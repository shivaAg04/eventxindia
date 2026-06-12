/// The role assigned to an authenticated user, which governs which features
/// and destinations the user may access (R3).
///
/// A user's role is established after authentication and profile setup, and is
/// the single source of truth the navigation layer uses to choose a start
/// destination and to block cross-role navigation (R3.1, R3.2). This is a pure
/// domain type, free of any backend representation: the data layer maps the
/// persisted `"student" | "vendor" | "admin"` string to and from these values.
enum UserRole {
  /// A student who discovers events, applies, checks in/out, and earns.
  student,

  /// A vendor who creates and manages events and decides applications.
  vendor,

  /// An administrator who approves vendors and oversees the platform.
  admin,
}
