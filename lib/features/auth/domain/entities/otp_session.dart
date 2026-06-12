import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/phone_number.dart';

/// A pending one-time-password (OTP) verification challenge (R1.1, R2.1).
///
/// An [OtpSession] is created when an OTP is requested for a [phone] and
/// represents the in-flight challenge a user must answer. It holds the
/// backend-issued [verificationId] (an opaque token the verify step echoes
/// back to the backend) and the [sentAt] timestamp used to enforce the OTP
/// validity window (R1.2, R2.3).
///
/// This is a pure domain entity: [verificationId] is a plain opaque string, so
/// no backend type (e.g. a Firebase verification id) crosses this boundary.
class OtpSession extends Equatable {
  const OtpSession({
    required this.verificationId,
    required this.phone,
    required this.sentAt,
  });

  /// The opaque, backend-issued token that identifies this OTP challenge.
  ///
  /// The verify step passes this back to the [AuthRepository] so the backend
  /// can correlate the submitted code with the delivered OTP.
  final String verificationId;

  /// The phone number the OTP was delivered to.
  final PhoneNumber phone;

  /// When the OTP was sent, used to enforce the validity window (R1.2, R2.3).
  final DateTime sentAt;

  /// Returns a copy of this session with the given fields replaced.
  OtpSession copyWith({
    String? verificationId,
    PhoneNumber? phone,
    DateTime? sentAt,
  }) {
    return OtpSession(
      verificationId: verificationId ?? this.verificationId,
      phone: phone ?? this.phone,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[verificationId, phone, sentAt];

  @override
  String toString() => 'OtpSession('
      'verificationId: $verificationId, '
      'phone: $phone, '
      'sentAt: $sentAt)';
}
