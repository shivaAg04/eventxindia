import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/features/earnings/data/mappers/money_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyMapper.fromDecimal', () {
    test('maps null to Money.zero (empty earnings, R11.5)', () {
      expect(MoneyMapper.fromDecimal(null), Money.zero);
    });

    test('maps 0 to Money.zero', () {
      expect(MoneyMapper.fromDecimal(0), Money.zero);
    });

    test('maps a decimal major-unit amount to Money exactly', () {
      expect(MoneyMapper.fromDecimal(123.45), Money.fromMajorUnits(123.45));
    });

    test('maps an integer amount to Money', () {
      expect(MoneyMapper.fromDecimal(42), Money.fromMajorUnits(42));
    });

    test('accepts accumulated totals above the single pay-per-head bound', () {
      // 10,000,000.00 exceeds maxPayPerHeadMinorUnits but is a valid total.
      final Money total = MoneyMapper.fromDecimal(10000000);
      expect(total.minorUnits, 1000000000);
    });
  });
}
