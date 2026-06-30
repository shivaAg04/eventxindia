import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/auth_user.dart';
import '../entities/otp_session.dart';
import '../entities/user_role.dart';
import '../logic/otp_policy.dart';
import '../repositories/auth_repository.dart';

/// Verifies a submitted OTP code, enforcing the validity window and the
/// consecutive-invalid attempt/lockout policy (R1.2, R1.3, R1.4, R2.3, R2.4,
/// R2.5).
///
/// The use case orchestrates the two pure policy functions in
/// `logic/otp_policy.dart` against the [AuthRepository]:
///
/// 1. **Window guard** ([isWithinOtpWindow]) — if the OTP was delivered more
///    than [otpValidityWindow] (300s) ago (or the clock is before delivery),
///    the attempt is treated as invalid without contacting the repository: the
///    code can no longer be accepted (R1.3, R2.3).
/// 2. **Match** ([AuthRepository.verifyOtp]) — within the window, the
///    repository decides whether [code] matches the issued OTP, returning the
///    authenticated [AuthUser] on success (R1.2, R2.3).
/// 3. **Attempt/lockout reduction** ([reduceAttempt]) — each result folds into
///    the per-phone [OtpAttemptState]: an accepted code resets the counter; the
///    5th consecutive invalid attempt locks a student/admin phone for 900s
///    (R1.4) or invalidates a vendor's OTP, requiring a new one (R2.5).
///
/// Before doing any of the above, a phone that is already locked / has an
/// invalidated OTP is rejected up front (R1.4, R2.5).
///
/// The attempt state is held per-phone in memory for the lifetime of this use
/// case instance; the clock is injected so the policy stays deterministic and
/// testable.
class VerifyOtp {
  VerifyOtp(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AuthRepository _repository;
  final DateTime Function() _clock;

  /// Per-phone consecutive-invalid attempt/lockout state, keyed by the phone's
  /// canonical E.164 form.
  final Map<String, OtpAttemptState> _attempts = <String, OtpAttemptState>{};

  /// Verifies [code] for the pending [session] on behalf of a user with the
  /// given [role].
  ///
  /// Returns the authenticated [AuthUser] on success, or an [AuthFailure]
  /// describing why verification was rejected (invalid/expired, locked, or
  /// OTP-invalidated).
  Future<Result<AuthUser, Failure>> call({
    required OtpSession session,
    required String code,
    required UserRole role,
  }) async {
    final String key = session.phone.e164;
    final DateTime now = _clock();
    final OtpAttemptState current = _attempts[key] ?? OtpAttemptState.initial;

    // Reject up front when the phone is already locked or the OTP was
    // invalidated by prior attempts (R1.4, R2.5).
    if (current.isBlockedAt(now)) {
      return Result<AuthUser, Failure>.err(_blockedFailure(current));
    }

    // Window guard: an expired OTP can never be accepted (R1.3, R2.3).
    final bool withinWindow = isWithinOtpWindow(
      sentAt: session.sentAt,
      now: now,
    );

    if (!withinWindow) {
      _attempts[key] = reduceAttempt(
        current,
        accepted: false,
        role: role,
        now: now,
      );
      return Result<AuthUser, Failure>.err(
        _invalidFailure(_attempts[key]!, expired: true),
      );
    }

    // Within the window: the repository decides whether the code matches the
    // issued OTP (R1.2, R2.3).
    final Result<AuthUser, Failure> result =
        await _repository.verifyOtp(session, code);

    // A registration-required result means the code WAS accepted (a session
    // now exists) but the user has no role yet — it is not an invalid attempt,
    // so it must reset the counter like a success and propagate unchanged for
    // the presentation layer to route to registration (R3.4).
    final bool verified =
        result.isOk || result.failureOrNull is RegistrationRequiredFailure;

    _attempts[key] = reduceAttempt(
      current,
      accepted: verified,
      role: role,
      now: now,
    );

    if (verified) {
      return result;
    }

    return Result<AuthUser, Failure>.err(
      _invalidFailure(_attempts[key]!, expired: false),
    );
  }

  Failure _blockedFailure(OtpAttemptState state) {
    if (state.otpInvalidated) {
      return const AuthFailure(
        message: 'Too many attempts. Please request a new OTP.',
      );
    }
    return const AuthFailure(
      message: 'This phone number is temporarily locked. Try again later.',
    );
  }

  Failure _invalidFailure(OtpAttemptState state, {required bool expired}) {
    if (state.otpInvalidated) {
      return const AuthFailure(
        message: 'Too many attempts. Please request a new OTP.',
      );
    }
    if (state.lockedUntil != null) {
      return const AuthFailure(
        message:
            'Too many attempts. This phone number is temporarily locked.',
      );
    }
    return AuthFailure(
      message: expired
          ? 'The OTP has expired. Please request a new one.'
          : 'The OTP is invalid. Please try again.',
    );
  }
}
