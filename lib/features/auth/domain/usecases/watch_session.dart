import '../entities/session_state.dart';
import '../repositories/auth_repository.dart';

/// Streams the current [SessionState] for the role-based navigation layer
/// (R3.3, R3.4).
///
/// [WatchSession] is a thin orchestration over [AuthRepository.watchSession]:
/// it exposes the repository's session stream so the router can react to
/// transitions between the three mutually-exclusive states:
///
/// * [Unauthenticated] — no signed-in user; the auth flow is shown (R3.4).
/// * [AuthenticatedNoRole] — signed in but no resolved role yet, so no
///   role-specific destination is offered (R3.4).
/// * [Authenticated] — signed in with a resolved role (R3.3).
///
/// Keeping this behind a use case means the presentation layer depends only on
/// the domain, never on the [AuthRepository] implementation directly.
class WatchSession {
  const WatchSession(this._repository);

  final AuthRepository _repository;

  /// Returns the stream of [SessionState] values, emitting a new value on every
  /// authentication-state change (R3.3, R3.4).
  Stream<SessionState> call() => _repository.watchSession();
}
