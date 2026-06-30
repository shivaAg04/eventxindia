part of 'auth_bloc.dart';

/// Base type for all [AuthBloc] states rendered by the auth screens.
///
/// States are compared by [Equatable] so the widget layer rebuilds only on a
/// genuine state change and `bloc_test` can assert exact emission sequences.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The idle/initial state: no OTP in flight and no signed-in user (R3.4).
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// An OTP delivery request is in progress (after [OtpRequested]).
final class OtpSending extends AuthState {
  const OtpSending();
}

/// An OTP has been delivered and the bloc awaits the user's code (R1.1, R2.1).
final class OtpSent extends AuthState {
  const OtpSent(this.session);

  /// The pending challenge describing the delivered OTP.
  final OtpSession session;

  @override
  List<Object?> get props => <Object?>[session];
}

/// A submitted OTP code is being verified (after [OtpSubmitted]).
final class Verifying extends AuthState {
  const Verifying();
}

/// Authentication succeeded; the user is signed in with the resolved [role]
/// (R3.3, R3.4). The router uses this to choose the start destination.
final class Authenticated extends AuthState {
  const Authenticated(this.role);

  /// The role of the signed-in user.
  final UserRole role;

  @override
  List<Object?> get props => <Object?>[role];
}

/// Authentication succeeded but the signed-in user has no role/profile yet, so
/// no role-specific destination is available; the app routes to registration /
/// the no-role screen (R3.4). The router maps this to the domain
/// `AuthenticatedNoRole` session state.
final class AuthenticatedNoRole extends AuthState {
  const AuthenticatedNoRole();
}

/// Authentication failed for a non-lockout reason — e.g. an invalid or expired
/// OTP, or an invalidated OTP that requires a fresh request
/// (R1.2, R1.3, R2.3, R2.5).
final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  /// A human-readable description of why authentication failed.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// The phone number is temporarily locked after too many invalid attempts
/// (R1.4, R2.4).
///
/// [until] is the instant the lock lifts when known; it may be `null` when the
/// failure only carries a message, in which case [message] conveys the detail.
final class PhoneLocked extends AuthState {
  const PhoneLocked({this.until, required this.message});

  /// When the lock lifts, when known; otherwise `null`.
  final DateTime? until;

  /// A human-readable description of the lockout.
  final String message;

  @override
  List<Object?> get props => <Object?>[until, message];
}
