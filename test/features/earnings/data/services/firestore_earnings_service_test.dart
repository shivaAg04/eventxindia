import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/earnings/data/services/firestore_earnings_service.dart';
import 'package:eventxindia/features/earnings/domain/entities/earnings.dart';
import 'package:eventxindia/features/earnings/domain/repositories/earnings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEarningsRepository extends Mock implements EarningsRepository {}

void main() {
  late _MockEarningsRepository repository;
  late FirestoreEarningsService service;

  setUp(() {
    repository = _MockEarningsRepository();
    service = FirestoreEarningsService(repository);
  });

  group('accrue', () {
    test('credits payPerHead once for a new event (R11.1)', () async {
      when(() => repository.getByStudent('s1'))
          .thenAnswer((_) async => Result<Earnings, Failure>.ok(
                Earnings.empty('s1'),
              ));

      final Result<Earnings, Failure> result = await service.accrue(
        studentId: 's1',
        eventId: 'e1',
        payPerHead: Money.fromMajorUnits(150),
      );

      expect(result.isOk, isTrue);
      final Earnings earnings = result.valueOrNull!;
      expect(earnings.total, Money.fromMajorUnits(150));
      expect(earnings.perEvent['e1'], Money.fromMajorUnits(150));
    });

    test('is idempotent for an already-credited event (R11.2)', () async {
      final Earnings existing = Earnings(
        studentId: 's1',
        total: Money.fromMajorUnits(150),
        perEvent: <String, Money>{'e1': Money.fromMajorUnits(150)},
      );
      when(() => repository.getByStudent('s1'))
          .thenAnswer((_) async => Result<Earnings, Failure>.ok(existing));

      final Result<Earnings, Failure> result = await service.accrue(
        studentId: 's1',
        eventId: 'e1',
        payPerHead: Money.fromMajorUnits(150),
      );

      expect(result.valueOrNull, existing);
    });

    test('propagates a repository read failure', () async {
      when(() => repository.getByStudent('s1')).thenAnswer(
        (_) async => const Result<Earnings, Failure>.err(PersistenceFailure()),
      );

      final Result<Earnings, Failure> result = await service.accrue(
        studentId: 's1',
        eventId: 'e1',
        payPerHead: Money.fromMajorUnits(150),
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<PersistenceFailure>());
    });
  });
}
