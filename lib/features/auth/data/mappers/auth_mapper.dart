import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/logic/otp_policy.dart';
import '../dtos/auth_throttle_dto.dart';

/// Mappers bridging Firebase/Firestore auth representations to and from the
/// pure auth domain (`AuthUser`, `UserRole`, `OtpAttemptState`).
///
/// This is the only place that knows how to read the persisted `users/{uid}`
/// document and the Firebase [fb.User], and how to translate the
/// application-level `authThrottle` DTO into the pure domain attempt/lockout
/// state. No Firebase type leaves these functions — callers only receive pure
/// domain values (design "Backend independence").
class AuthMapper {
  const AuthMapper._();

  /// Parses the persisted `role` string into a [UserRole].
  ///
  /// Returns `null` for a missing or unknown value so the repository can emit
  /// `AuthenticatedNoRole` rather than guessing a role (R3.4).
  static UserRole? roleFromString(String? raw) {
    switch (raw) {
      case 'student':
        return UserRole.student;
      case 'vendor':
        return UserRole.vendor;
      case 'staff':
        return UserRole.staff;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }

  /// Serializes a [UserRole] to its persisted string form.
  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'student';
      case UserRole.vendor:
        return 'vendor';
      case UserRole.staff:
        return 'staff';
      case UserRole.admin:
        return 'admin';
    }
  }

  /// Builds the pure [AuthUser] from a signed-in Firebase [user] and its
  /// persisted `users/{uid}` document [data].
  ///
  /// The [role] and [phone] are read from the Firestore document when present,
  /// falling back to the Firebase user's own phone number. Returns `null` when
  /// no role can be resolved or no phone is available, signalling the
  /// authenticated-but-no-role state (R3.4).
  static AuthUser? authUserFromFirebase(
    fb.User user,
    Map<String, dynamic>? data,
  ) {
    final UserRole? role = roleFromString(data?['role'] as String?);
    if (role == null) {
      return null;
    }

    final String? rawPhone =
        (data?['phone'] as String?) ?? user.phoneNumber;
    if (rawPhone == null || rawPhone.isEmpty) {
      return null;
    }

    final PhoneNumber? phone = _tryParsePhone(rawPhone);
    if (phone == null) {
      return null;
    }

    return AuthUser(uid: user.uid, role: role, phone: phone);
  }

  /// Folds an [AuthThrottleDto] read from Firestore into the pure domain
  /// [OtpAttemptState] used by the verify policy (R1.4, R2.4, R2.5).
  static OtpAttemptState attemptStateFromDto(AuthThrottleDto dto) {
    return OtpAttemptState(
      consecutiveInvalid: dto.failedCount,
      lockedUntil: dto.lockedUntil,
      // A vendor OTP is invalidated once attempts hit the limit; we surface
      // that as `otpInvalidated` so the repository blocks further verifies on
      // the dead OTP until a new one is requested (R2.5).
      otpInvalidated: dto.attemptsForCurrentOtp >= maxOtpAttempts,
    );
  }

  /// Produces the persisted [AuthThrottleDto] for [phone] from the running
  /// domain [state], preserving the OTP-issued timestamp ([otpIssuedAt]).
  static AuthThrottleDto attemptStateToDto({
    required String phone,
    required OtpAttemptState state,
    DateTime? otpIssuedAt,
  }) {
    return AuthThrottleDto(
      phone: phone,
      otpIssuedAt: otpIssuedAt,
      attemptsForCurrentOtp: state.consecutiveInvalid,
      failedCount: state.consecutiveInvalid,
      lockedUntil: state.lockedUntil,
    );
  }

  static PhoneNumber? _tryParsePhone(String raw) {
    try {
      return PhoneNumber.parse(raw);
    } on FormatException {
      return null;
    }
  }
}

/// Convenience extension used by the repository to read a `users/{uid}`
/// document snapshot's role without leaking the snapshot type outward.
extension UserRoleSnapshot on DocumentSnapshot<Map<String, dynamic>> {
  /// The resolved [UserRole] from this `users/{uid}` document, or `null` when
  /// missing/unknown.
  UserRole? get roleOrNull => AuthMapper.roleFromString(data()?['role'] as String?);
}
