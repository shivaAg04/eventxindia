import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/domain/entities/session_state.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart' as auth;
import '../features/navigation/domain/entities/destination.dart';
import 'destination_screen_factory.dart';
import 'role_router_controller.dart';

/// The application's role-based router (R3).
///
/// [RoleRouter] is a widget that maps the current [SessionState] plus the
/// selected [Destination] to a home screen. It is deliberately simpler than a
/// full Navigator 2.0 [RouterDelegate]: it owns a [RoleRouterController] that
/// holds the guard logic and rebuilds the active screen whenever the resolved
/// destination changes.
///
/// Session source: by default it derives the [SessionState] from [AuthBloc] by
/// reading the bloc from the widget tree (R3.4). The [AuthBloc] is a
/// presentation state machine over the same auth use cases, so its
/// [auth.Authenticated]/[auth.AuthInitial] states map cleanly onto
/// [SessionState]. A custom [sessionStream] may be supplied instead (e.g. a
/// `WatchSession` stream) for tests or direct domain wiring.
///
/// The router never mutates the session: blocking cross-role navigation only
/// changes the selected destination (R3.2).
class RoleRouter extends StatefulWidget {
  const RoleRouter({
    super.key,
    this.screenFactory = defaultDestinationScreenFactory,
    this.sessionStream,
    this.initialSession = const Unauthenticated(),
    this.controller,
  });

  /// Maps a resolved [Destination] to the widget that renders it.
  final DestinationScreenFactory screenFactory;

  /// An optional explicit session source. When `null`, the router subscribes to
  /// the ambient [AuthBloc] (R3.4).
  final Stream<SessionState>? sessionStream;

  /// The session state to render before the first stream/bloc event arrives.
  final SessionState initialSession;

  /// An optional pre-built controller, primarily for testing. When `null`, the
  /// router creates one seeded with [initialSession].
  final RoleRouterController? controller;

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final RoleRouterController _controller;
  StreamSubscription<SessionState>? _sessionSubscription;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        RoleRouterController(session: widget.initialSession);
    _ownsController = widget.controller == null;

    if (widget.sessionStream != null) {
      _sessionSubscription =
          widget.sessionStream!.listen(_controller.updateSession);
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// Maps an [AuthBloc] state to the domain [SessionState] (R3.4).
  ///
  /// The bloc collapses "authenticated with no role" to [auth.AuthInitial], so
  /// only [auth.Authenticated] yields a resolved role; every other auth state
  /// (idle, OTP in flight, failure, lockout) is treated as unauthenticated for
  /// navigation purposes, keeping the user on the auth screen.
  SessionState _sessionFromAuthState(auth.AuthState state) {
    return switch (state) {
      auth.Authenticated(:final role) => Authenticated(role),
      _ => const Unauthenticated(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // When no explicit session stream is provided, drive the controller from
    // the ambient AuthBloc.
    final Widget routed = AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) =>
          widget.screenFactory(_controller.current),
    );

    if (widget.sessionStream != null) {
      return routed;
    }

    return BlocListener<auth.AuthBloc, auth.AuthState>(
      listener: (BuildContext context, auth.AuthState state) {
        _controller.updateSession(_sessionFromAuthState(state));
      },
      child: routed,
    );
  }
}
