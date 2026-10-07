import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/validators/app_validators.dart';

void main() {
  group('AppValidators.email', () {
    final v = AppValidators.email();
    test('requires a value', () => expect(v(''), 'Email is required'));
    test('rejects bad email', () => expect(v('guru@'), isNotNull));
    test('accepts good email', () => expect(v('guru@natyakosha.app'), isNull));
  });

  group('AppValidators.indianPhone', () {
    final v = AppValidators.indianPhone();
    test('accepts 10 digits starting 6-9', () => expect(v('9876543210'), isNull));
    test('accepts +91 prefix and spaces', () => expect(v('+91 98765 43210'), isNull));
    test('rejects numbers starting 1-5', () => expect(v('5876543210'), isNotNull));
    test('rejects short numbers', () => expect(v('98765'), isNotNull));
  });

  group('AppValidators.optionalUpiId', () {
    final v = AppValidators.optionalUpiId();
    test('allows empty', () => expect(v(''), isNull));
    test('accepts name@bank', () => expect(v('guru.lakshmi@okhdfcbank'), isNull));
    test('rejects missing handle', () => expect(v('guru'), isNotNull));
    test('rejects spaces', () => expect(v('guru lakshmi@bank'), isNotNull));
  });

  group('AppValidators.amount', () {
    final v = AppValidators.amount();
    test('requires a value', () => expect(v(null), 'Amount is required'));
    test('rejects zero', () => expect(v('0'), isNotNull));
    test('rejects letters', () => expect(v('12a'), isNotNull));
    test('rejects 3 decimals', () => expect(v('10.999'), isNotNull));
    test('accepts 1500', () => expect(v('1500'), isNull));
    test('accepts 1500.50', () => expect(v('1500.50'), isNull));
  });

  group('AppValidators.optionalUpiTxnId', () {
    final v = AppValidators.optionalUpiTxnId();
    test('empty is allowed', () => expect(v(''), isNull));
    test('12 digits ok', () => expect(v('412345678901'), isNull));
    test('11 digits rejected', () => expect(v('41234567890'), isNotNull));
  });
}
