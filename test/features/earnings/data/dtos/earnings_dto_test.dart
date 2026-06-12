import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/earnings/data/dtos/earnings_dto.dart';
import 'package:eventxindia/features/earnings/domain/entities/earnings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> snapshot(
    String id, {
    Map<String, dynamic>? data,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        firestore.collection('earnings').doc(id);
    if (data != null) {
      await ref.set(data);
    }
    return ref.get();
  }

  group('EarningsDto.fromFirestore', () {
    test('parses total and perEvent into Money (R11.3, R11.4)', () async {
      final EarningsDto dto = EarningsDto.fromFirestore(
        await snapshot(
          's1',
          data: <String, dynamic>{
            'studentId': 's1',
            'total': 300.50,
            'perEvent': <String, dynamic>{
              'e1': 100.25,
              'e2': 200.25,
            },
          },
        ),
      );

      expect(dto.studentId, 's1');
      expect(dto.total, Money.fromMajorUnits(300.50));
      expect(dto.perEvent['e1'], Money.fromMajorUnits(100.25));
      expect(dto.perEvent['e2'], Money.fromMajorUnits(200.25));
    });

    test('falls back to document id when studentId field is absent', () async {
      final EarningsDto dto = EarningsDto.fromFirestore(
        await snapshot('s9', data: <String, dynamic>{'total': 10}),
      );

      expect(dto.studentId, 's9');
    });

    test('degrades missing total and perEvent to empty projection (R11.5)',
        () async {
      final EarningsDto dto = EarningsDto.fromFirestore(
        await snapshot('s1', data: <String, dynamic>{'studentId': 's1'}),
      );

      expect(dto.total, Money.zero);
      expect(dto.perEvent, isEmpty);
    });
  });

  group('EarningsDto.toEntity', () {
    test('produces a pure domain Earnings entity', () {
      final EarningsDto dto = EarningsDto(
        studentId: 's1',
        total: Money.fromMajorUnits(150),
        perEvent: <String, Money>{'e1': Money.fromMajorUnits(150)},
      );

      final Earnings entity = dto.toEntity();

      expect(entity.studentId, 's1');
      expect(entity.total, Money.fromMajorUnits(150));
      expect(entity.perEvent['e1'], Money.fromMajorUnits(150));
    });
  });
}
