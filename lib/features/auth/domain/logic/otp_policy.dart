import 'package:equatable/equatable.dart';

import '../entities/user_role.dart';

/// Pure, backend-agnostic OTP acceptance and attempt/lockout policy
/// (R1.2, R1.3, R1.4, R2.3, R2.4, R2.5).
///
/// This file holds two side-effect-free pieces of business logic that the
/// `VerifyOtp` use case orchestrates and that are exercised directly by the
/// property tests (Properties 1 and 2):
///
/// * [isOtpAcceptable] — the acceptance window: a submitted code is accepted
///   **iff** it matches the issued code **and** it is submitted within
///   [otpValidityWindow] (300s) of delivery.
/// * [reduceAttempt] — the consecutive-invalid attempt counter and lockout
///   reducer: a valid attempt resets the counter; the 5th consecutive invalid
///   attempt either locks a student/admin phone for [studentLockoutDuration]
///   (900s) or invalidates the OTP for a vendor, requiring a new one.

/// How long an issued OTP remains acceptable after delivery (R1.2, R2.3).
const Duration otpValidityWindow = Duration(seconds: 300);

/// The number of consecutive invalid attempts that triggers a lockout /
/// OTP invalidation (R1.4, R2.4, R2.5).
const int maxOtpAttempts = 5;

/// How long a student/admin phone is locked after the limit is reached (R1.4).
const Duration studentLockoutDuration = Duration(seconds: 900);

/// Returns `true` when [submittedCode] should be accepted for the OTP issued at
/// [sentAt], evaluated at [now] (R1.2, R1.3, R2.3).
///
/// Acceptance requires **both**:
/// * an exact match between [submittedCode] and [issuedCode], and
/// * submission within [window] of [sentAt] — that is `0 <= now - sentAt <=
///   window`. A submission before [sentAt] (negative elapsed) or after the
///   window closes is rejected.
///
/// This is a pure function: it performs no I/O and reads no clock of its own,
/// taking [now] as an argument so it is deterministic and property-testable
/// (Property 1).
bool isOtpAcceptable({
  required String issuedCode,
  required String submittedCode,
  required DateTime sentAt,
  required DateTime now,
  Duration window = otpValidityWindow,
}) {
  if (submittedCode != issuedCode) {
    return false;
  }
  final Duration elapsed = now.difference(sentAt);
  return !elapsed.isNegative && elapsed <= window;
}

/// Returns `true` when an OTP issued at [sentAt] is still within its validity
/// [window] at [now] — i.e. `0 <= now - sentAt <= window` (R1.2, R2.3).
///
/// This is the timing half of [isOtpAcceptable], split out so callers that do
/// not hold the issued code (e.g. the client-side `VerifyOtp` use case, where
/// the code match is performed by the backend) can still guard the window
/// before delegating the match.
bool isWithinOtpWindow({
  required DateTime sentAt,
  required DateTime now,
  Duration window = otpValidityWindow,
}) {
  final Duration elapsed = now.difference(sentAt);
  return !elapsed.isNegative && elapsed <= window;
}

/// The result of folding a single verification attempt into the running
/// consecutive-invalid state for a phone/OTP (R1.4, R2.4, R2.5).
///
/// * [consecutiveInvalid] — the running count of consecutive invalid attempts;
///   reset to `0` after any accepted attempt.
/// * [lockedUntil] — for a student/admin, the instant until which further OTP
///   attempts are blocked once the limit is hit (R1.4); `null` when not locked.
/// * [otpInvalidated] — for a vendor, `true` once the limit is hit, signalling
///   the current OTP is dead and a new one must be requested (R2.5).
class OtpAttemptState extends Equatable {
  const OtpAttemptState({
    this.consecutiveInvalid = 0,
    this.lockedUntil,
    this.otpInvalidated = false,
  });

  /// The starting state for a fresh phone/OTP: no invalid attempts, unlocked.
  static const OtpAttemptState initial = OtpAttemptState();

  /// Count of consecutive invalid attempts (reset on a valid attempt).
  final int consecutiveInvalid;

  /// When set, the phone is locked to new OTP attempts until this instant
  /// (student/admin lockout, R1.4).
  final DateTime? lockedUntil;

  /// Whether the current OTP has been invalidated and a new one is required
  /// (vendor, R2.5).
  final bool otpInvalidated;

  /// Whether this state currently blocks further verification, either because
  /// the phone is locked at [now] or the OTP has been invalidated.
  bool isBlockedAt(DateTime now) {
    if (otpInvalidated) {
      return true;
    }
    final DateTime? until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  @override
  List<Object?> get props =>
      <Object?>[consecutiveInvalid, lockedUntil, otpInvalidated];

  @override
  String toString() => 'OtpAttemptState('
      'consecutiveInvalid: $consecutiveInvalid, '
      'lockedUntil: $lockedUntil, '
      'otpInvalidated: $otpInvalidated)';
}

/// Folds a single verification result into [previous], producing the next
/// attempt/lockout state for the given [role] (R1.4, R2.4, R2.5).
///
/// Behaviour:
/// * **Accepted** attempt ([accepted] `true`): the counter resets to `0` and no
///   lock or invalidation is applied.
/// * **Invalid** attempt: the counter increments by one.
///   * Below [maxAttempts] (5): only the counter changes; up to 5 attempts are
///     allowed per OTP (R2.4).
///   * At or above [maxAttempts] (the 5th consecutive invalid): for a
///     [UserRole.student]/[UserRole.admin] the phone is locked until
///     `now + [lockoutDuration]` (R1.4); for a [UserRole.vendor] the OTP is
///     invalidated, requiring a new one (R2.5).
///
/// Pure and deterministic — [now] is supplied by the caller — so it is directly
/// property-testable (Property 2).
OtpAttemptState reduceAttempt(
  OtpAttemptState previous, {
  required bool accepted,
  required UserRole role,
  required DateTime now,
  int maxAttempts = maxOtpAttempts,
  Duration lockoutDuration = studentLockoutDuration,
}) {
  if (accepted) {
    return OtpAttemptState.initial;
  }

  final int nextCount = previous.consecutiveInvalid + 1;

  if (nextCount < maxAttempts) {
    return OtpAttemptState(
      consecutiveInvalid: nextCount,
      lockedUntil: previous.lockedUntil,
      otpInvalidated: previous.otpInvalidated,
    );
  }

  // Limit reached on this attempt: apply the role-specific consequence.
  switch (role) {
    case UserRole.student:
    case UserRole.staff:
    case UserRole.admin:
      return OtpAttemptState(
        consecutiveInvalid: nextCount,
        lockedUntil: now.add(lockoutDuration),
      );
    case UserRole.vendor:
      return OtpAttemptState(
        consecutiveInvalid: nextCount,
        otpInvalidated: true,
      );
  }
}
