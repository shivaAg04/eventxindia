import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/admin/data/datasources/firestore_metrics_data_source.dart';
import 'package:eventxindia/features/admin/data/services/firestore_metrics_service.dart';
import 'package:eventxindia/features/admin/domain/entities/metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements FirestoreMetricsDataSource {}

class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockDataSource dataSource;
  late FirestoreMetricsService service;

  setUp(() {
    dataSource = _MockDataSource();
    service = FirestoreMetricsService(dataSource);
  });

  DocumentSnapshot<Map<String, dynamic>> snapshot(Map<String, dynamic>? data) {
    final _MockDocumentSnapshot doc = _MockDocumentSnapshot();
    when(doc.data).thenReturn(data);
    return doc;
  }

  group('watchMetrics', () {
    test('maps the metrics/global document to a domain Metrics (R6.7)',
        () async {
      when(dataSource.watchGlobal).thenAnswer(
        (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
          snapshot(<String, dynamic>{
            'totalStudents': 12,
            'totalVendors': 4,
            'activeEvents': 3,
            'completedEvents': 7,
          }),
        ),
      );

      final Metrics metrics = await service.watchMetrics().first;

      expect(metrics.totalStudents, 12);
      expect(metrics.totalVendors, 4);
      expect(metrics.activeEvents, 3);
      expect(metrics.completedEvents, 7);
    });

    test('emits Metrics.zero before any aggregation has run (missing doc)',
        () async {
      when(dataSource.watchGlobal).thenAnswer(
        (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
          snapshot(null),
        ),
      );

      final Metrics metrics = await service.watchMetrics().first;

      expect(metrics, Metrics.zero);
    });

    test('treats missing/negative counters as zero', () async {
      when(dataSource.watchGlobal).thenAnswer(
        (_) => Stream<DocumentSnapshot<Map<String, dynamic>>>.value(
          snapshot(<String, dynamic>{
            'totalStudents': -5,
            'activeEvents': 2,
          }),
        ),
      );

      final Metrics metrics = await service.watchMetrics().first;

      expect(metrics.totalStudents, 0);
      expect(metrics.totalVendors, 0);
      expect(metrics.activeEvents, 2);
      expect(metrics.completedEvents, 0);
    });
  });

  group('getMetrics', () {
    test('returns an Ok with the mapped Metrics on success', () async {
      when(dataSource.getGlobal).thenAnswer(
        (_) async => snapshot(<String, dynamic>{
          'totalStudents': 1,
          'totalVendors': 2,
          'activeEvents': 3,
          'completedEvents': 4,
        }),
      );

      final Result<Metrics, Failure> result = await service.getMetrics();

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull,
        Metrics(
          totalStudents: 1,
          totalVendors: 2,
          activeEvents: 3,
          completedEvents: 4,
        ),
      );
    });

    test('returns a PersistenceFailure when the read throws', () async {
      when(dataSource.getGlobal).thenThrow(Exception('boom'));

      final Result<Metrics, Failure> result = await service.getMetrics();

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<PersistenceFailure>());
    });
  });
}
