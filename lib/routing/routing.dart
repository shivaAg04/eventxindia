/// Role-based routing for the EventXIndia platform (R3).
///
/// This barrel re-exports the routing building blocks so callers can depend on
/// a single import:
///
/// * [RoleRouter] — the widget that maps session + destination to a screen.
/// * [RoleRouterController] — the pure guard logic (start destination + cross
///   role navigation blocking).
/// * [DestinationScreenFactory] / [defaultDestinationScreenFactory] — the
///   destination → screen mapping seam.
library;

export 'destination_screen_factory.dart';
export 'role_router.dart';
export 'role_router_controller.dart';
