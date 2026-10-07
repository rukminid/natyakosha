import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/payment_repository.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';

PaymentRepository get _repo => locator<PaymentRepository>();

AppThunk loadPayments() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null) return;
      store.dispatch(const PaymentsRequestAction());
      try {
        store.dispatch(PaymentsLoadedAction(await _repo.fetchFor(user)));
      } catch (e) {
        store.dispatch(PaymentsFailureAction(AppException.from(e).message));
      }
    };

/// Uploads the screenshot (with progress) and records the payment.
/// [onSuccess] lets the view pop the screen once it's saved.
AppThunk submitPayment({
  required String month,
  required double amount,
  required String screenshotPath,
  String? upiTxnId,
  String? note,
  void Function()? onSuccess,
}) =>
    (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null) return;
      if (!store.state.isOnline) {
        store.dispatch(PaymentSubmitFailedAction(AppException.offline.message));
        return;
      }
      store.dispatch(const PaymentSubmitStartAction());
      try {
        final payment = await _repo.submit(
          student: user,
          month: month,
          amount: amount,
          screenshotPath: screenshotPath,
          upiTxnId: upiTxnId,
          note: note,
          onProgress: (p) => store.dispatch(PaymentUploadProgressAction(p)),
        );
        store.dispatch(PaymentSubmittedAction(payment));
        onSuccess?.call();
      } catch (e) {
        store.dispatch(PaymentSubmitFailedAction(AppException.from(e).message));
      }
    };

/// Guru verifies (approve = true) or rejects a submitted payment.
AppThunk reviewPayment(String paymentId, {required bool approve, String? note}) =>
    (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.role.isStaff) return;
      store.dispatch(PaymentReviewStartAction(paymentId));
      try {
        await _repo.review(
          schoolId: user.schoolId,
          paymentId: paymentId,
          approve: approve,
          reviewerId: user.id,
          note: note,
        );
        store.dispatch(PaymentReviewedAction(
          paymentId,
          approve ? PaymentStatus.verified : PaymentStatus.rejected,
          user.id,
        ));
      } catch (e) {
        store.dispatch(PaymentReviewFailedAction(paymentId, AppException.from(e).message));
      }
    };
