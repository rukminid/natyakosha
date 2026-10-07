import 'package:redux/redux.dart';

import '../actions/app_actions.dart';
import '../state/payments_state.dart';

final paymentsReducer = combineReducers<PaymentsState>([
  TypedReducer<PaymentsState, PaymentsRequestAction>(
    (s, _) => s.copyWith(loading: true, error: () => null),
  ).call,
  TypedReducer<PaymentsState, PaymentsLoadedAction>(
    (s, a) => s.copyWith(items: a.items, loading: false),
  ).call,
  TypedReducer<PaymentsState, PaymentsFailureAction>(
    (s, a) => s.copyWith(loading: false, error: () => a.message),
  ).call,
  TypedReducer<PaymentsState, PaymentSubmitStartAction>(
    (s, _) => s.copyWith(submitting: true, uploadProgress: 0, submitError: () => null),
  ).call,
  TypedReducer<PaymentsState, PaymentUploadProgressAction>(
    (s, a) => s.copyWith(uploadProgress: a.progress),
  ).call,
  TypedReducer<PaymentsState, PaymentSubmittedAction>(
    (s, a) => s.copyWith(
      submitting: false,
      uploadProgress: 1,
      items: [a.payment, ...s.items],
    ),
  ).call,
  TypedReducer<PaymentsState, PaymentSubmitFailedAction>(
    (s, a) => s.copyWith(submitting: false, uploadProgress: 0, submitError: () => a.message),
  ).call,
  TypedReducer<PaymentsState, PaymentReviewStartAction>(
    (s, a) => s.copyWith(reviewingIds: {...s.reviewingIds, a.paymentId}),
  ).call,
  TypedReducer<PaymentsState, PaymentReviewedAction>(
    (s, a) => s.copyWith(
      reviewingIds: {...s.reviewingIds}..remove(a.paymentId),
      items: [
        for (final p in s.items)
          p.id == a.paymentId
              ? p.copyWith(status: a.status, verifiedBy: a.reviewerId, verifiedAt: DateTime.now())
              : p,
      ],
    ),
  ).call,
  TypedReducer<PaymentsState, PaymentReviewFailedAction>(
    (s, a) => s.copyWith(
      reviewingIds: {...s.reviewingIds}..remove(a.paymentId),
      error: () => a.message,
    ),
  ).call,
]);
