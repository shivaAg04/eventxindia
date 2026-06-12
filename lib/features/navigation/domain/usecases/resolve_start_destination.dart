import '../../../auth/domain/entities/session_state.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../entities/destination.dart';

/// Pure resolver for the start (landing) destination given a [SessionState]
/// (R3.1, R3.3, R3.4).
///
/// The mapping is total and exhaustive over the sealed [SessionState]:
///
/// - [Unauthenticated] → [Destination.authentication]: an unauthenticated user
///   is denied all role-based navigation and redirected to the auth screen
///   (R3.4).
/// - [AuthenticatedNoRole] → [Destination.noRole]: an authenticated user with
///   no assigned role sees no role-specific destinations (R3.3).
/// - [Authenticated] with a recognized [UserRole] → that role's default
///   destination (R3.1). An unrecognized role value cannot occur because the
///   role is modelled as the closed [UserRole] enum; any value outside it is
///   rejected at the parsing boundary in the auth layer, collapsing to
///   [AuthenticatedNoRole] and thus [Destination.noRole] (R3.3).
///
/// This is a pure function with no dependencies, making it directly
/// example/property-testable.
class ResolveStartDestination {
  const ResolveStartDestination();

  /// Resolves the destination the application should land on for [session].
  Destination call(SessionState session) {
    return switch (session) {
      Unauthenticated() => Destination.authentication,
      AuthenticatedNoRole() => Destination.noRole,
      Authenticated(:final UserRole role) => role.defaultDestination,
    };
  }
}
