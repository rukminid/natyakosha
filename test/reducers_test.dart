import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/payment.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';

const _guru = AppUser(id: 'g1', name: 'Guru Lakshmi', role: UserRole.guru, schoolId: 's1');

Payment _payment(String id, PaymentStatus status, {String month = '2026-10', double amount = 1500}) =>
    Payment(
      id: id,
      studentId: 'st1',
      studentName: 'Ananya',
      month: month,
      amount: amount,
      status: status,
    );

void main() {
  test('sign-in success stores the user and marks authenticated', () {
    final s = appReducer(AppState.initial(), const AuthSuccessAction(_guru));
    expect(s.auth.status, AuthStatus.authenticated);
    expect(s.auth.user, _guru);
  });

  test('sign-in failure keeps an error and marks unauthenticated', () {
    final s = appReducer(AppState.initial(), const AuthFailureAction('Wrong password'));
    expect(s.auth.status, AuthStatus.unauthenticated);
    expect(s.auth.error, 'Wrong password');
  });

  test('connectivity action flips isOnline', () {
    final s = appReducer(AppState.initial(), const SetConnectivityAction(isOnline: false));
    expect(s.isOnline, isFalse);
  });

  test('sign-out clears data but keeps connectivity', () {
    var s = appReducer(AppState.initial(), const AuthSuccessAction(_guru));
    s = appReducer(s, PaymentsLoadedAction([_payment('p1', PaymentStatus.verified)]));
    s = appReducer(s, const SetConnectivityAction(isOnline: false));
    s = appReducer(s, const SignedOutAction());
    expect(s.auth.user, isNull);
    expect(s.payments.items, isEmpty);
    expect(s.isOnline, isFalse);
  });

  test('reviewing a payment updates its status and clears the spinner', () {
    var s = appReducer(AppState.initial(), PaymentsLoadedAction([_payment('p1', PaymentStatus.submitted)]));
    s = appReducer(s, const PaymentReviewStartAction('p1'));
    expect(s.payments.reviewingIds, contains('p1'));
    s = appReducer(s, const PaymentReviewedAction('p1', PaymentStatus.verified, 'g1'));
    expect(s.payments.reviewingIds, isEmpty);
    expect(s.payments.items.single.status, PaymentStatus.verified);
  });

  test('selectors: awaiting review and collected this month', () {
    final s = appReducer(
      AppState.initial(),
      PaymentsLoadedAction([
        _payment('a', PaymentStatus.submitted),
        _payment('b', PaymentStatus.verified, amount: 1500),
        _payment('c', PaymentStatus.verified, amount: 2000),
        _payment('d', PaymentStatus.verified, month: '2026-09', amount: 999),
      ]),
    );
    expect(paymentsAwaitingReview(s).length, 1);
    expect(collectedThisMonth(s, now: DateTime(2026, 10, 15)), 3500);
  });
}
