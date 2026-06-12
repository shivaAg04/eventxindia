import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore DTO for the application-level OTP throttle record
/// (`authThrottle/{phone}`), the data-layer state backing the attempt-counting
/// and lockout requirements (R1.4, R2.4, R2.5).
///
/// Firebase OTP delivery/verification and native rate limiting are
/// platform-provided; this record holds the *application-specific* counters and
/// lockout window that the domain policy (`OtpAttemptState`) is expressed in.
/// It is the only place Firebase [Timestamp] appears for auth throttling — the
/// `AuthThrottleMapper` converts it to/from the pure domain `OtpAttemptState`.
///
/// Persisted shape (per design "authThrottle/{phone}"):
/// ```
/// {
///   phone: string,
///   otpIssuedAt?: Timestamp,
///   attemptsForCurrentOtp: number,  // resets on new OTP (R2.5)
///   failedCount: number,            // consecutive invalids (R1.4)
///   lockedUntil?: Timestamp         // set when locked 900s (R1.4)
/// }
/// ```
class AuthThrottleDto {
  const AuthThrottleDto({
    required this.phone,
    this.otpIssuedAt,
    this.attemptsForCurrentOtp = 0,
    this.failedCount = 0,
    this.lockedUntil,
  });

  /// The canonical E.164 phone string this throttle record is keyed on.
  final String phone;

  /// When the current OTP was issued, or `null` when none is outstanding.
  final DateTime? otpIssuedAt;

  /// Invalid attempts made against the current OTP; reset when a new OTP is
  /// issued (R2.5).
  final int attemptsForCurrentOtp;

  /// Running count of consecutive invalid attempts (R1.4).
  final int failedCount;

  /// The instant until which further attempts are blocked, or `null` when not
  /// locked (R1.4).
  final DateTime? lockedUntil;

  /// Reads a throttle DTO from a Firestore document.
  ///
  /// A non-existent or empty document maps to a fresh record for [fallbackId]
  /// with zeroed counters and no lock.
  factory AuthThrottleDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? fallbackId,
  }) {
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return AuthThrottleDto(phone: fallbackId ?? doc.id);
    }
    return AuthThrottleDto.fromMap(data, fallbackId: fallbackId ?? doc.id);
  }

  /// Reads a throttle DTO from a raw Firestore map.
  factory AuthThrottleDto.fromMap(
    Map<String, dynamic> data, {
    String? fallbackId,
  }) {
    return AuthThrottleDto(
      phone: (data['phone'] as String?) ?? fallbackId ?? '',
      otpIssuedAt: (data['otpIssuedAt'] as Timestamp?)?.toDate(),
      attemptsForCurrentOtp: (data['attemptsForCurrentOtp'] as num?)?.toInt() ?? 0,
      failedCount: (data['failedCount'] as num?)?.toInt() ?? 0,
      lockedUntil: (data['lockedUntil'] as Timestamp?)?.toDate(),
    );
  }

  /// Serializes this DTO to a Firestore-writable map.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'phone': phone,
      'otpIssuedAt':
          otpIssuedAt == null ? null : Timestamp.fromDate(otpIssuedAt!),
      'attemptsForCurrentOtp': attemptsForCurrentOtp,
      'failedCount': failedCount,
      'lockedUntil':
          lockedUntil == null ? null : Timestamp.fromDate(lockedUntil!),
    };
  }

  /// Returns a copy of this DTO with the given fields replaced.
  AuthThrottleDto copyWith({
    String? phone,
    DateTime? otpIssuedAt,
    int? attemptsForCurrentOtp,
    int? failedCount,
    DateTime? lockedUntil,
    bool clearOtpIssuedAt = false,
    bool clearLockedUntil = false,
  }) {
    return AuthThrottleDto(
      phone: phone ?? this.phone,
      otpIssuedAt:
          clearOtpIssuedAt ? null : (otpIssuedAt ?? this.otpIssuedAt),
      attemptsForCurrentOtp:
          attemptsForCurrentOtp ?? this.attemptsForCurrentOtp,
      failedCount: failedCount ?? this.failedCount,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    );
  }
}
