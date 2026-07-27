part of 'auth_bloc.dart';

/// Base type for all [AuthBloc] events (UI intents in the auth flow).
///
/// Events are pure value objects compared by [Equatable], so duplicate
/// intents are deduplicated by `bloc_test` and equality checks.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Requests delivery of an OTP for [rawPhone] under the chosen [role]
/// (R1.1, R2.1).
///
/// The raw, unvalidated phone string is passed through; [RequestOtp] performs
/// role-specific format validation before asking for an OTP.
final class OtpRequested extends AuthEvent {
  const OtpRequested({required this.rawPhone, required this.role});

  /// The user-entered phone string, validated downstream by [RequestOtp].
  final String rawPhone;

  /// The role the user is signing in as, governing phone-format and
  /// attempt/lockout rules.
  final UserRole role;

  @override
  List<Object?> get props => <Object?>[rawPhone, role];
}

/// Submits the user-entered OTP [code] for the pending challenge
/// (R1.2, R1.3, R2.3).
final class OtpSubmitted extends AuthEvent {
  const OtpSubmitted(this.code);

  /// The OTP code entered by the user.
  final String code;

  @override
  List<Object?> get props => <Object?>[code];
}

/// Starts watching the session stream so the bloc reflects sign-in state
/// changes (R3.4).
final class SessionWatchStarted extends AuthEvent {
  const SessionWatchStarted();
}

/// Signals that the signed-in user just completed registration for [role], so
/// the bloc can move straight to [Authenticated] and the router can navigate to
/// the role's home immediately — without waiting for the `users/{uid}` role
/// write to round-trip back through the Firestore-backed session watcher (which
/// can be slow or, on a flaky connection, not arrive at all).
final class RoleRegistered extends AuthEvent {
  const RoleRegistered(this.role);

  /// The role the user just registered as.
  final UserRole role;

  @override
  List<Object?> get props => <Object?>[role];
}

/// Signs the current user out and clears any in-flight OTP challenge.
final class SignedOut extends AuthEvent {
  const SignedOut();
}
