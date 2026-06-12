import 'package:eventxindia/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FieldError', () {
    test('is value-equal by field and message', () {
      expect(
        const FieldError(field: 'fullName', message: 'required'),
        const FieldError(field: 'fullName', message: 'required'),
      );
    });
  });

  group('Failure codes', () {
    test('each concrete failure carries its stable code', () {
      expect(const ValidationFailure().code, 'validation');
      expect(const AuthFailure().code, 'auth');
      expect(const AuthorizationFailure().code, 'authorization');
      expect(const StateTransitionFailure().code, 'state_transition');
      expect(const LocationFailure().code, 'location');
      expect(const PersistenceFailure().code, 'persistence');
      expect(const NotFoundFailure().code, 'not_found');
    });
  });

  group('ValidationFailure', () {
    test('carries field errors', () {
      const failure = ValidationFailure(
        message: 'invalid form',
        fieldErrors: <FieldError>[
          FieldError(field: 'city', message: 'required'),
          FieldError(field: 'height', message: 'out of bounds'),
        ],
      );

      expect(failure.fieldErrors, hasLength(2));
      expect(failure.fieldErrors.first.field, 'city');
    });

    test('defaults to an empty field-error list', () {
      expect(const AuthFailure().fieldErrors, isEmpty);
    });
  });

  group('value equality', () {
    test('two failures with the same code/message/fields are equal', () {
      expect(
        const ValidationFailure(
          message: 'x',
          fieldErrors: <FieldError>[FieldError(field: 'a', message: 'b')],
        ),
        const ValidationFailure(
          message: 'x',
          fieldErrors: <FieldError>[FieldError(field: 'a', message: 'b')],
        ),
      );
    });

    test('different failure types are not equal', () {
      expect(const AuthFailure(), isNot(const AuthorizationFailure()));
    });
  });
}
