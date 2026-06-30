import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/otp_session.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/logic/otp_policy.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';
import '../dtos/auth_throttle_dto.dart';
import '../mappers/auth_mapper.dart';

/// Firebase-backed [AuthRepository] (R1.4, R2.1, R2.4, R2.5, R14.1).
///
/// Implements the domain auth gateway over [FirebaseAuthDataSource]:
/// * [requestOtp] enforces the persisted lockout before asking Firebase to
///   deliver an OTP, then resets the per-OTP attempt counter (R2.1, R2.5).
/// * [verifyOtp] rejects blocked phones up front, delegates the code match to
///   Firebase Phone Auth, and folds the result into the persisted
///   `authThrottle` record so attempt counting/lockout survives across app
///   sessions (R1.4, R2.4, R2.5).
/// * [watchSession] maps Firebase auth-state changes plus the `users/{uid}`
///   role to the pure [SessionState] (R3.3, R3.4).
///
/// All persisted writes go through the [withRetry] policy (R14.6). No Firebase
/// type crosses out of this class — only pure domain entities and
/// `Result<T, Failure>` are returned.
@LazySingleton(as: AuthRepository)
class FirebaseAuthRepositoryImpl implements AuthRepository {
  @factoryMethod
  FirebaseAuthRepositoryImpl.inject(this._dataSource)
      : _clock = DateTime.now,
        _maxWriteAttempts = kDefaultMaxWriteAttempts;

  FirebaseAuthRepositoryImpl(
    this._dataSource, {
    DateTime Function()? clock,
    int maxWriteAttempts = kDefaultMaxWriteAttempts,
  })  : _clock = clock ?? DateTime.now,
        _maxWriteAttempts = maxWriteAttempts;

  final FirebaseAuthDataSource _dataSource;
  final DateTime Function() _clock;
  final int _maxWriteAttempts;

  @override
  Future<Result<OtpSession, Failure>> requestOtp(PhoneNumber phone) async {
    final String key = phone.e164;
    final DateTime now = _clock();

    // Enforce the persisted lockout before requesting delivery (R1.4, R2.5).
    final AuthThrottleDto existing = await _readThrottleSafe(key);
    final OtpAttemptState state = AuthMapper.attemptStateFromDto(existing);
    if (state.lockedUntil != null && now.isBefore(state.lockedUntil!)) {
      return const Result<OtpSession, Failure>.err(
        AuthFailure(
          message:
              'This phone number is temporarily locked. Try again later.',
        ),
      );
    }

    final String verificationId;
    try {
      verificationId = await _dataSource.requestOtp(key);
    } on fb.FirebaseAuthException catch (error) {
      return Result<OtpSession, Failure>.err(_authFailureFrom(error));
    } on TimeoutException {
      return const Result<OtpSession, Failure>.err(
        AuthFailure(message: 'Timed out sending the OTP. Please try again.'),
      );
    }

    // A new OTP resets the per-OTP attempt counter (R2.5) while preserving any
    // active lockout window (R1.4).
    // Best-effort: record the freshly issued OTP in the throttle ledger.
    // Throttle/lockout state is trusted backend-owned (authThrottle is closed
    // to clients by Firestore rules), so a denied or failed write must not
    // block OTP delivery — consistent with the safe read in
    // [_readThrottleSafe] and the best-effort [_persistThrottle].
    await withRetry<void>(
      _maxWriteAttempts,
      () => _dataSource.writeThrottle(
        existing.copyWith(
          otpIssuedAt: now,
          attemptsForCurrentOtp: 0,
        ),
      ),
    );

    return Result<OtpSession, Failure>.ok(
      OtpSession(verificationId: verificationId, phone: phone, sentAt: now),
    );
  }

  @override
  Future<Result<AuthUser, Failure>> verifyOtp(
    OtpSession session,
    String code,
  ) async {
    final String key = session.phone.e164;
    final DateTime now = _clock();

    final AuthThrottleDto throttle = await _readThrottleSafe(key);
    final OtpAttemptState current = AuthMapper.attemptStateFromDto(throttle);

    // Reject blocked phones (locked window or invalidated OTP) up front
    // (R1.4, R2.5).
    if (current.isBlockedAt(now)) {
      return Result<AuthUser, Failure>.err(_blockedFailure(current));
    }

    fb.User user;
    try {
      user = await _dataSource.verifyOtp(session.verificationId, code);
    } on fb.FirebaseAuthException catch (error) {
      // The code did not match / has expired: fold the invalid attempt into
      // the persisted throttle (R1.3, R2.4, R2.5). Role is unknown at the data
      // boundary, so a conservative lockout (student-style 900s window) is
      // applied at the limit; role-specific messaging lives in the use case.
      final OtpAttemptState next = _reduceInvalid(current, now);
      await _persistThrottle(key, next, otpIssuedAt: throttle.otpIssuedAt);
      return Result<AuthUser, Failure>.err(
        _invalidFailure(next, _authFailureFrom(error)),
      );
    }

    // Verified: reset the attempt/lockout state for this phone (R2.4).
    await _persistThrottle(
      key,
      OtpAttemptState.initial,
      otpIssuedAt: null,
    );

    final DocumentSnapshot<Map<String, dynamic>> userDoc =
        await _dataSource.readUserDoc(user.uid);
    final AuthUser? authUser =
        AuthMapper.authUserFromFirebase(user, userDoc.data());

    if (authUser == null) {
      // Verified but no role assigned yet. The code WAS accepted (a session
      // exists), so this is not a verification failure: surface a distinct
      // registration-required signal so the flow routes to registration
      // (the no-role session state) instead of counting an invalid attempt.
      // Navigation is also driven by [watchSession], which emits
      // AuthenticatedNoRole for this user (R3.4).
      return const Result<AuthUser, Failure>.err(
        RegistrationRequiredFailure(),
      );
    }

    return Result<AuthUser, Failure>.ok(authUser);
  }

  @override
  Stream<SessionState> watchSession() {
    return _dataSource.authStateChanges().asyncExpand((fb.User? user) {
      if (user == null) {
        return Stream<SessionState>.value(const Unauthenticated());
      }
      return _dataSource.watchUserDoc(user.uid).map(
        (DocumentSnapshot<Map<String, dynamic>> doc) {
          final UserRole? role = doc.roleOrNull;
          if (role == null) {
            return const AuthenticatedNoRole();
          }
          return Authenticated(role);
        },
      );
    });
  }

  @override
  Future<Result<Unit, Failure>> signOut() async {
    final Result<void, Failure> result = await withRetry<void>(
      _maxWriteAttempts,
      _dataSource.signOut,
    );
    return result.map((_) => unit);
  }

  // --- internals -----------------------------------------------------------

  Future<AuthThrottleDto> _readThrottleSafe(String key) async {
    try {
      return await _dataSource.readThrottle(key);
    } catch (_) {
      // A read failure should not block the auth flow; treat as a fresh record.
      return AuthThrottleDto(phone: key);
    }
  }

  /// Increments the consecutive-invalid counter and, on reaching the limit,
  /// applies a conservative lockout window (R1.4, R2.4, R2.5).
  OtpAttemptState _reduceInvalid(OtpAttemptState current, DateTime now) {
    final int next = current.consecutiveInvalid + 1;
    if (next < maxOtpAttempts) {
      return OtpAttemptState(
        consecutiveInvalid: next,
        lockedUntil: current.lockedUntil,
        otpInvalidated: current.otpInvalidated,
      );
    }
    // Limit reached: lock the phone (student/admin, R1.4) and mark the OTP
    // invalidated (vendor, R2.5) so both flows are blocked at the data layer.
    return OtpAttemptState(
      consecutiveInvalid: next,
      lockedUntil: now.add(studentLockoutDuration),
      otpInvalidated: true,
    );
  }

  Future<void> _persistThrottle(
    String key,
    OtpAttemptState state, {
    DateTime? otpIssuedAt,
  }) async {
    final AuthThrottleDto dto = AuthMapper.attemptStateToDto(
      phone: key,
      state: state,
      otpIssuedAt: otpIssuedAt,
    );
    await withRetry<void>(
      _maxWriteAttempts,
      () => _dataSource.writeThrottle(dto),
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

  Failure _invalidFailure(OtpAttemptState state, AuthFailure fallback) {
    if (state.otpInvalidated || state.lockedUntil != null) {
      return const AuthFailure(
        message: 'Too many attempts. Please request a new OTP.',
      );
    }
    return fallback;
  }

  AuthFailure _authFailureFrom(fb.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-verification-code':
        return const AuthFailure(
          message: 'The OTP is invalid. Please try again.',
        );
      case 'session-expired':
      case 'code-expired':
        return const AuthFailure(
          message: 'The OTP has expired. Please request a new one.',
        );
      case 'invalid-phone-number':
        return const AuthFailure(message: 'The phone number is invalid.');
      case 'too-many-requests':
        return const AuthFailure(
          message: 'Too many requests. Please try again later.',
        );
      default:
        return AuthFailure(
          message: error.message ?? 'Authentication failed.',
        );
    }
  }
}
