import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../entities/auth_user.dart';
import '../entities/otp_session.dart';
import '../entities/session_state.dart';

/// Abstract gateway for authentication and session observation.
///
/// This is the domain-owned swap line for auth: use cases depend only on this
/// interface, and a backend-specific implementation (today Firebase Auth,
/// later a REST/WebSocket backend) lives in the data layer. No backend types
/// ever cross this boundary — every method speaks pure domain values
/// ([PhoneNumber], [OtpSession], [AuthUser], [SessionState]) and
/// `Result<T, Failure>`.
abstract class AuthRepository {
  /// Requests delivery of a one-time password to [phone].
  ///
  /// On success returns the [OtpSession] describing the in-flight challenge
  /// (its opaque verification id and send time). Returns a failure when the
  /// OTP cannot be delivered, e.g. the phone is locked or attempts are
  /// exhausted (R1.4, R2.5).
  Future<Result<OtpSession, Failure>> requestOtp(PhoneNumber phone);

  /// Verifies the user-entered [code] against the pending [session].
  ///
  /// On success returns the authenticated [AuthUser]. Returns an
  /// [AuthFailure] when the code does not match or the OTP has expired
  /// (R1.2, R1.3, R2.3, R2.4).
  Future<Result<AuthUser, Failure>> verifyOtp(OtpSession session, String code);

  /// Streams the current [SessionState], emitting a new value whenever the
  /// authentication state changes (R3.3, R3.4).
  Stream<SessionState> watchSession();

  /// Signs the current user out, returning [unit] on success.
  Future<Result<Unit, Failure>> signOut();
}
