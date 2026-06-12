import 'package:bloc_test/bloc_test.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/earnings/domain/entities/earnings.dart';
import 'package:eventxindia/features/earnings/domain/usecases/get_earnings.dart';
import 'package:eventxindia/features/earnings/presentation/bloc/earnings_bloc.dart';
import 'package:eventxindia/features/earnings/presentation/bloc/earnings_event.dart';
import 'package:eventxindia/features/earnings/presentation/bloc/earnings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetEarnings extends Mock implements GetEarnings {}

void main() {
  late _MockGetEarnings getEarnings;

  setUp(() {
    getEarnings = _MockGetEarnings();
  });

  EarningsBloc build() => EarningsBloc(getEarnings);

  group('EarningsBloc', () {
    test('initial state is EarningsLoading', () {
      expect(build().state, const EarningsLoading());
    });

    blocTest<EarningsBloc, EarningsState>(
      'emits [Loading, Loaded] with total and per-event credits (R11.3, R11.4)',
      setUp: () {
        final earnings = Earnings(
          studentId: 's1',
          total: Money.fromMinorUnits(15000, requirePayPerHeadRange: false),
          perEvent: <String, Money>{
            'e1': Money.fromMinorUnits(10000),
            'e2': Money.fromMinorUnits(5000),
          },
        );
        when(() => getEarnings(studentId: 's1'))
            .thenAnswer((_) => Stream<Earnings>.value(earnings));
      },
      build: build,
      act: (bloc) => bloc.add(const EarningsWatchStarted('s1')),
      expect: () => <EarningsState>[
        const EarningsLoading(),
        EarningsLoaded(
          total: Money.fromMinorUnits(15000, requirePayPerHeadRange: false),
          perEvent: <String, Money>{
            'e1': Money.fromMinorUnits(10000),
            'e2': Money.fromMinorUnits(5000),
          },
        ),
      ],
    );

    blocTest<EarningsBloc, EarningsState>(
      'emits [Loading, Empty] for a zero/empty projection (R11.5)',
      setUp: () {
        when(() => getEarnings(studentId: 's1')).thenAnswer(
          (_) => Stream<Earnings>.value(Earnings.empty('s1')),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const EarningsWatchStarted('s1')),
      expect: () => <EarningsState>[
        const EarningsLoading(),
        const EarningsEmpty(),
      ],
    );

    blocTest<EarningsBloc, EarningsState>(
      'emits [Loading, Failure] when the stream errors (R4.7)',
      setUp: () {
        when(() => getEarnings(studentId: 's1'))
            .thenAnswer((_) => Stream<Earnings>.error(Exception('boom')));
      },
      build: build,
      act: (bloc) => bloc.add(const EarningsWatchStarted('s1')),
      expect: () => <Matcher>[
        equals(const EarningsLoading()),
        isA<EarningsFailure>(),
      ],
    );
  });
}
