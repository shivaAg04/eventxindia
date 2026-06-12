import 'package:eventxindia/core/value_objects/geo_point.dart';
import 'package:eventxindia/features/events/domain/entities/event_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final geo = GeoPoint(latitude: 12.34, longitude: 56.78);

  group('EventLocation', () {
    test('trims the label and exposes the geo', () {
      final location = EventLocation(label: '  Venue Hall  ', geo: geo);
      expect(location.label, 'Venue Hall');
      expect(location.geo, geo);
    });

    test('accepts a 1-character label (lower bound)', () {
      expect(EventLocation(label: 'A', geo: geo).label, 'A');
    });

    test('accepts a 200-character label (upper bound)', () {
      final label = 'x' * 200;
      expect(EventLocation(label: label, geo: geo).label, label);
    });

    test('rejects an empty or whitespace-only label', () {
      expect(() => EventLocation(label: '', geo: geo), throwsArgumentError);
      expect(() => EventLocation(label: '   ', geo: geo), throwsArgumentError);
    });

    test('rejects a label longer than 200 characters', () {
      expect(
        () => EventLocation(label: 'x' * 201, geo: geo),
        throwsArgumentError,
      );
    });

    test('is value-equal by label and geo', () {
      expect(
        EventLocation(label: 'Hall', geo: geo),
        EventLocation(label: 'Hall', geo: geo),
      );
    });

    test('copyWith replaces only the given fields', () {
      final location = EventLocation(label: 'Hall', geo: geo);
      final other = GeoPoint(latitude: 1, longitude: 2);
      expect(location.copyWith(label: 'Arena').label, 'Arena');
      expect(location.copyWith(geo: other).geo, other);
    });
  });
}
