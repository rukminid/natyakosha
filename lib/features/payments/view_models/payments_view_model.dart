import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/payment.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/payment_thunks.dart';

/// List screen: staff verify/reject screenshots, students see their history.
class PaymentsViewModel extends Equatable {
  const PaymentsViewModel({
    required this.items,
    required this.isStaff,
    required this.loading,
    required this.error,
    required this.reviewingIds,
    required this.isOnline,
    required this.refresh,
    required this.review,
  });

  final List<Payment> items;
  final bool isStaff;
  final bool loading;
  final String? error;
  final Set<String> reviewingIds;
  final bool isOnline;

  final Future<void> Function() refresh;
  final void Function(String paymentId, {required bool approve}) review;

  int get awaitingCount => items.where((p) => p.status == PaymentStatus.submitted).length;

  static PaymentsViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    return PaymentsViewModel(
      items: s.payments.items,
      isStaff: s.auth.user?.role.isStaff ?? false,
      loading: s.payments.loading,
      error: s.payments.error,
      reviewingIds: s.payments.reviewingIds,
      isOnline: s.isOnline,
      refresh: () async => store.dispatch(loadPayments()),
      review: (id, {required approve}) => store.dispatch(reviewPayment(id, approve: approve)),
    );
  }

  @override
  List<Object?> get props => [items, isStaff, loading, error, reviewingIds, isOnline];
}

/// Upload form: only needs submit state + the submit command.
class UploadPaymentViewModel extends Equatable {
  const UploadPaymentViewModel({
    required this.submitting,
    required this.progress,
    required this.error,
    required this.isOnline,
    required this.submit,
  });

  final bool submitting;
  final double progress;
  final String? error;
  final bool isOnline;

  final void Function({
    required String month,
    required double amount,
    required String screenshotPath,
    String? upiTxnId,
    String? note,
    void Function()? onSuccess,
  }) submit;

  static UploadPaymentViewModel fromStore(Store<AppState> store) => UploadPaymentViewModel(
        submitting: store.state.payments.submitting,
        progress: store.state.payments.uploadProgress,
        error: store.state.payments.submitError,
        isOnline: store.state.isOnline,
        submit: ({
          required month,
          required amount,
          required screenshotPath,
          upiTxnId,
          note,
          onSuccess,
        }) =>
            store.dispatch(submitPayment(
              month: month,
              amount: amount,
              screenshotPath: screenshotPath,
              upiTxnId: upiTxnId,
              note: note,
              onSuccess: onSuccess,
            )),
      );

  @override
  List<Object?> get props => [submitting, progress, error, isOnline];
}
