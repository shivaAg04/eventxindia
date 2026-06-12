import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/earnings/data/datasources/firestore_earnings_data_source.dart';
import 'package:eventxindia/features/earnings/data/repositories/firestore_earnings_repository_impl.dart';
import 'package:eventxindia/features/earnings/domain/entities/earnings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements FirestoreEarningsDataSource {}

class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockDataSource dataSource;
  late FirestoreEarningsRepositoryImpl repository;

  setUp(() {
    dataSource = _MockDataSource();
    repository = FirestoreEarningsRepositoryImpl(dataSource);
  });

  DocumentSnapshot<Map<String, dynamic>> snapshot({
    required String id,
    required bool exists,
    Map<String, dynamic>? data,
  }) {
    final _MockDocumentSnapshot doc = _MockDocumentSnapshot();
    when(() => doc.id).thenReturn(id);
    when(() => doc.exists).thenReturn(exists);
    when(doc.data).thenReturn(data);
    return doc;
  }

  group('watchByStudent', () {
    test('maps an existing document to a domain Earnings (R11.3, R11.4)',
        () async {
      when(() => dataSource.watchByStudent('s1')).thenAnswer(
        (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
          snapshot(
            id: 's1',
            exists: true,
            data: <String, dynamic>{
              'studentId': 's1',
              'total': 250,
              'perEvent': <String, dynamic>{'e1': 250},
            },
          ),
        ),
      );

      final Earnings earnings = await repository.watchByStudent('s1').first;

      expect(earnings.studentId, 's1');
      expect(earnings.total, Money.fromMajorUnits(250));
      expect(earnings.perEvent['e1'], Money.fromMajorUnits(250));
    });

    test('emits an empty projection when the document does not exist (R11.5)',
        () async {
      when(() => dataSource.watchByStudent('s1')).thenAnswer(
        (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
          snapshot(id: 's1', exists: false),
        ),
      );

      final Earnings earnings = await repository.watchByStudent('s1').first;

      expect(earnings, Earnings.empty('s1'));
      expect(earnings.total, Money.zero);
      expect(earnings.perEvent, isEmpty);
    });
  });

  group('getByStudent', () {
    test('returns an Ok with the mapped Earnings on success', () async {
      when(() => dataSource.getByStudent('s1')).thenAnswer(
        (_) async => snapshot(
          id: 's1',
          exists: true,
          data: <String, dynamic>{'total': 99.99},
        ),
      );

      final Result<Earnings, Failure> result =
          await repository.getByStudent('s1');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.total, Money.fromMajorUnits(99.99));
    });

    test('returns an empty projection when the document does not exist (R11.5)',
        () async {
      when(() => dataSource.getByStudent('s1')).thenAnswer(
        (_) async => snapshot(id: 's1', exists: false),
      );

      final Result<Earnings, Failure> result =
          await repository.getByStudent('s1');

      expect(result.valueOrNull, Earnings.empty('s1'));
    });

    test('returns a PersistenceFailure when the read throws', () async {
      when(() => dataSource.getByStudent('s1')).thenThrow(Exception('boom'));

      final Result<Earnings, Failure> result =
          await repository.getByStudent('s1');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<PersistenceFailure>());
    });
  });
}
