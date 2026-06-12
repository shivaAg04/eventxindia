import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// The observable authentication/session state of the app (R3.3, R3.4).
///
/// The navigation layer subscribes to a `Stream<SessionState>` to choose the
/// start destination and to gate cross-role navigation. The three variants are
/// mutually exclusive:
///
/// * [Unauthenticated] — no signed-in user; the auth flow is shown (R3.3).
/// * [AuthenticatedNoRole] — signed in but profile/role setup is incomplete,
///   so no role-specific destination is available yet (R3.4).
/// * [Authenticated] — signed in with a resolved [UserRole] (R3.3).
///
/// This is a pure, sealed domain type: exhaustive `switch` over its variants
/// is checked by the compiler.
sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// No user is signed in; the authentication flow should be shown (R3.3).
final class Unauthenticated extends SessionState {
  const Unauthenticated();

  @override
  String toString() => 'Unauthenticated()';
}

/// A user is signed in but has no resolved role yet, e.g. profile/role setup
/// is still pending (R3.4).
final class AuthenticatedNoRole extends SessionState {
  const AuthenticatedNoRole();

  @override
  String toString() => 'AuthenticatedNoRole()';
}

/// A user is signed in with a resolved [role] (R3.3).
final class Authenticated extends SessionState {
  const Authenticated(this.role);

  /// The role that determines the user's start destination and access.
  final UserRole role;

  @override
  List<Object?> get props => <Object?>[role];

  @override
  String toString() => 'Authenticated(role: $role)';
}
