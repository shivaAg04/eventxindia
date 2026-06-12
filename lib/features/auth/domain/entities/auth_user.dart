import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/phone_number.dart';
import 'user_role.dart';

/// An authenticated user identity (R3.3, R3.4).
///
/// An [AuthUser] is produced once OTP verification succeeds and carries the
/// stable [uid], the user's [role], and the verified [phone]. It is a pure
/// domain entity using only backend-neutral types ([PhoneNumber], [UserRole]):
/// the data layer maps the persisted `users/{uid}` document to and from this
/// shape, so it is unaffected by a future change of backend.
class AuthUser extends Equatable {
  const AuthUser({
    required this.uid,
    required this.role,
    required this.phone,
  });

  /// The stable unique identifier of the user.
  final String uid;

  /// The role that governs the user's access to features and destinations.
  final UserRole role;

  /// The verified phone number associated with the account.
  final PhoneNumber phone;

  /// Returns a copy of this user with the given fields replaced.
  AuthUser copyWith({
    String? uid,
    UserRole? role,
    PhoneNumber? phone,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      phone: phone ?? this.phone,
    );
  }

  @override
  List<Object?> get props => <Object?>[uid, role, phone];

  @override
  String toString() => 'AuthUser(uid: $uid, role: $role, phone: $phone)';
}
