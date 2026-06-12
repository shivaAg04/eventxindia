import '../../../auth/domain/entities/user_role.dart';
import '../entities/destination.dart';

/// Pure feature-authorization guard for role-based navigation (R3.2).
///
/// [Authorize] answers a single question: may a user with the given [UserRole]
/// access the given [Destination]? Access is granted **if and only if** the
/// destination belongs to that role — i.e. `feature.owner == role`. Shared,
/// non-role destinations (e.g. [Destination.authentication], [Destination.noRole])
/// belong to no role, so no role is authorized for them through this guard.
///
/// This is a pure function with no dependencies, which makes it directly
/// property-testable (Property 9): for any (role, feature) pair, the result is
/// exactly `feature.owner == role`.
class Authorize {
  const Authorize();

  /// Returns `true` when [role] is authorized to access [feature], i.e. when
  /// [feature] is one of that role's own destinations (R3.2).
  bool call(UserRole role, Destination feature) => feature.owner == role;
}
