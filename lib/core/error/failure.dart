import 'package:equatable/equatable.dart';

/// A single field-level validation error.
///
/// Used by [ValidationFailure] to report exactly which fields were missing or
/// out of bounds so the presentation layer can highlight them while retaining
/// the user's entered values (R1.7, R2.8).
class FieldError extends Equatable {
  const FieldError({required this.field, required this.message});

  /// The name of the offending field (e.g. `fullName`, `dateOfBirth`).
  final String field;

  /// A human-readable description of why the field is invalid.
  final String message;

  @override
  List<Object?> get props => <Object?>[field, message];

  @override
  String toString() => 'FieldError($field: $message)';
}

/// Base type for every domain error in the application.
///
/// Errors are modelled as *values*, not thrown exceptions: use cases and
/// repositories return a `Result<T, Failure>` so that BLoCs can translate a
/// failure into a state and preserve form input. Every failure carries a
/// machine-readable [code], a human-readable [message], and an optional set of
/// [fieldErrors] for form-level validation feedback.
sealed class Failure extends Equatable {
  const Failure({
    required this.code,
    required this.message,
    this.fieldErrors = const <FieldError>[],
  });

  /// A stable, machine-readable identifier for this failure (e.g.
  /// `validation`, `auth`, `not_found`). Useful for analytics and for mapping
  /// failures to UI states without depending on the human-readable [message].
  final String code;

  /// A human-readable description of what went wrong.
  final String message;

  /// Field-level errors, populated for validation failures and empty otherwise.
  final List<FieldError> fieldErrors;

  @override
  List<Object?> get props => <Object?>[code, message, fieldErrors];

  @override
  String toString() =>
      '$runtimeType(code: $code, message: $message, fieldErrors: $fieldErrors)';
}

/// A validation failure carrying one or more [FieldError]s.
///
/// Returned when input fails domain validation (e.g. an incomplete student or
/// vendor registration form, an invalid event input, or an invalid report).
/// The [fieldErrors] identify each non-conforming field (R1.7, R2.8).
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'One or more fields are invalid.',
    super.fieldErrors,
  }) : super(code: 'validation');
}

/// An authentication failure.
///
/// Returned for invalid/expired OTPs, locked phone numbers, exhausted OTP
/// attempts, and other sign-in problems (R1.x, R2.x).
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed.',
  }) : super(code: 'auth');
}

/// Signals that OTP verification succeeded and a session now exists, but the
/// signed-in user has no role/profile yet and must complete registration
/// before any role-based destination is available (R3.4).
///
/// This is deliberately **not** an [AuthFailure]: the code was accepted, so the
/// auth flow must route to registration (the no-role session state) rather than
/// treat it as an invalid attempt or increment the lockout counter.
class RegistrationRequiredFailure extends Failure {
  const RegistrationRequiredFailure({
    super.message =
        'Your profile is incomplete. Please complete registration.',
  }) : super(code: 'registration_required');
}

/// An authorization failure.
///
/// Returned when an authenticated user attempts to access a feature or perform
/// an action that their assigned role does not permit (R3.2).
class AuthorizationFailure extends Failure {
  const AuthorizationFailure({
    super.message = 'You are not authorized to perform this action.',
  }) : super(code: 'authorization');
}

/// An invalid state-transition failure.
///
/// Returned when an entity cannot move to the requested state — for example an
/// application or vendor approval that is not in the required `Pending` state,
/// or an event status change that violates the allowed set (R5.8, R6.3, R9.5).
class StateTransitionFailure extends Failure {
  const StateTransitionFailure({
    super.message = 'The requested state transition is not allowed.',
  }) : super(code: 'state_transition');
}

/// A location/GPS failure.
///
/// Returned when a device location cannot be obtained in time or is outside the
/// acceptable distance of an event during attendance check-in (R10.3, R10.4).
class LocationFailure extends Failure {
  const LocationFailure({
    super.message = 'Location validation failed.',
  }) : super(code: 'location');
}

/// A persistence failure.
///
/// Returned when a write to the backing store fails (including after the
/// write-retry policy is exhausted, with no partial data committed) (R14.6).
class PersistenceFailure extends Failure {
  const PersistenceFailure({
    super.message = 'A storage operation failed. Please try again.',
  }) : super(code: 'persistence');
}

/// A not-found failure.
///
/// Returned when a requested entity (event, application, profile, etc.) does
/// not exist in the backing store.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'The requested resource was not found.',
  }) : super(code: 'not_found');
}
