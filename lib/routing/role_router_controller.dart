import 'package:flutter/foundation.dart';

import '../features/auth/domain/entities/session_state.dart';
import '../features/auth/domain/entities/user_role.dart';
import '../features/navigation/domain/entities/destination.dart';
import '../features/navigation/domain/usecases/authorize.dart';
import '../features/navigation/domain/usecases/resolve_start_destination.dart';

/// Drives role-based navigation from the observed [SessionState] (R3).
///
/// [RoleRouterController] is the pure-Dart brain of the router: it owns the
/// current [SessionState] and the currently selected [Destination], and exposes
/// the two guarded operations the UI needs:
///
/// * [updateSession] — react to a session change by resolving the start
///   destination via [ResolveStartDestination]. Unauthenticated sessions land
///   on [Destination.authentication] (R3.4); authenticated-but-no/unknown-role
///   sessions land on [Destination.noRole] (R3.3); a recognized role lands on
///   that role's default destination (R3.1).
/// * [navigateTo] — attempt to move to a destination, blocking any cross-role
///   navigation via [Authorize]. An unauthorized destination is rejected and
///   the user is returned to the role's default destination, never mutating the
///   session (R3.2).
///
/// As a [ChangeNotifier] it notifies listeners (the router widget) whenever the
/// resolved destination changes, so the widget rebuilds the correct screen. It
/// has no Flutter-widget dependency, keeping the guard logic unit-testable.
class RoleRouterController extends ChangeNotifier {
  RoleRouterController({
    SessionState session = const Unauthenticated(),
    ResolveStartDestination resolveStartDestination =
        const ResolveStartDestination(),
    Authorize authorize = const Authorize(),
  })  : _session = session,
        _resolveStartDestination = resolveStartDestination,
        _authorize = authorize,
        _current = resolveStartDestination(session);

  final ResolveStartDestination _resolveStartDestination;
  final Authorize _authorize;

  SessionState _session;
  Destination _current;

  /// The session state the router is currently reflecting.
  SessionState get session => _session;

  /// The destination whose screen the router is currently showing.
  Destination get current => _current;

  /// The role of the current session, or `null` when there is no resolved role
  /// (unauthenticated or authenticated-no-role).
  UserRole? get currentRole => switch (_session) {
        Authenticated(:final UserRole role) => role,
        Unauthenticated() => null,
        AuthenticatedNoRole() => null,
      };

  /// The destinations the current role may see, or an empty list when there is
  /// no resolved role (R3.1, R3.3).
  List<Destination> get visibleDestinations {
    final UserRole? role = currentRole;
    if (role == null) {
      return const <Destination>[];
    }
    return role.destinations;
  }

  /// Reacts to a new [session]: re-resolves the start destination and, if it
  /// changed, notifies listeners (R3.1, R3.3, R3.4).
  ///
  /// This always re-bases the current destination on the new session so a
  /// sign-out or role change can never strand the user on a destination they
  /// are no longer allowed to see.
  void updateSession(SessionState session) {
    final bool sessionChanged = session != _session;
    final Destination resolved = _resolveStartDestination(session);
    final bool destinationChanged = resolved != _current;

    if (!sessionChanged && !destinationChanged) {
      return;
    }

    _session = session;
    _current = resolved;
    notifyListeners();
  }

  /// Attempts to navigate to [destination], enforcing role ownership (R3.2).
  ///
  /// Returns `true` when navigation is permitted and applied; returns `false`
  /// when it is blocked (cross-role or no resolved role), in which case the
  /// router falls back to the role's default destination and the session is
  /// left untouched (R3.2).
  bool navigateTo(Destination destination) {
    final UserRole? role = currentRole;

    // With no resolved role there are no authorized role destinations; remain
    // on the resolved start destination (auth / no-role) without change (R3.3).
    if (role == null) {
      return false;
    }

    if (_authorize(role, destination)) {
      if (destination != _current) {
        _current = destination;
        notifyListeners();
      }
      return true;
    }

    // Cross-role navigation: block it and return to the role's default
    // destination without altering the session (R3.2).
    final Destination fallback = role.defaultDestination;
    if (fallback != _current) {
      _current = fallback;
      notifyListeners();
    }
    return false;
  }
}
