import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/value_objects/money.dart';
import '../../../../core/value_objects/withdrawal_status.dart';
import '../../domain/entities/withdrawal_request.dart';

/// Firebase data-transfer object for a `withdrawals/{id}` document.
///
/// The only place Firebase types (`DocumentSnapshot`, `Timestamp`) touch the
/// [WithdrawalRequest] shape. The amount is stored as exact integer minor units
/// (paise) to avoid floating-point drift, matching the [Money] representation.
class WithdrawalRequestDto {
  const WithdrawalRequestDto({
    required this.id,
    required this.studentId,
    required this.amountMinorUnits,
    required this.status,
    required this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String studentId;
  final int amountMinorUnits;
  final String status;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// Parses a Firestore `withdrawals/{id}` document into a DTO.
  factory WithdrawalRequestDto.fromFirestore(fs.DocumentSnapshot<Object?> doc) {
    final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return WithdrawalRequestDto(
      id: data['id'] as String? ?? doc.id,
      studentId: data['studentId'] as String,
      amountMinorUnits: (data['amountMinorUnits'] as num).toInt(),
      status: data['status'] as String,
      createdAt: (data['createdAt'] as fs.Timestamp).toDate(),
      decidedAt: (data['decidedAt'] as fs.Timestamp?)?.toDate(),
    );
  }

  /// Builds a DTO from a pure domain [WithdrawalRequest] (outbound mapping).
  factory WithdrawalRequestDto.fromEntity(WithdrawalRequest request) {
    return WithdrawalRequestDto(
      id: request.id,
      studentId: request.studentId,
      amountMinorUnits: request.amount.minorUnits,
      status: request.status.wireName,
      createdAt: request.createdAt,
      decidedAt: request.decidedAt,
    );
  }

  /// Serialises this DTO to a Firestore-ready map.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'id': id,
      'studentId': studentId,
      'amountMinorUnits': amountMinorUnits,
      'status': status,
      'createdAt': fs.Timestamp.fromDate(createdAt),
      if (decidedAt != null) 'decidedAt': fs.Timestamp.fromDate(decidedAt!),
    };
  }

  /// Converts this DTO to a pure domain [WithdrawalRequest] (inbound mapping).
  WithdrawalRequest toEntity() {
    return WithdrawalRequest(
      id: id,
      studentId: studentId,
      amount: Money.fromMinorUnits(
        amountMinorUnits,
        requirePayPerHeadRange: false,
      ),
      status: WithdrawalStatusX.tryParse(status) ?? WithdrawalStatus.pending,
      createdAt: createdAt,
      decidedAt: decidedAt,
    );
  }
}
