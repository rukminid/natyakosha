import 'package:equatable/equatable.dart';

import '../../data/models/payment.dart';

class PaymentsState extends Equatable {
  const PaymentsState({
    this.items = const [],
    this.loading = false,
    this.submitting = false,
    this.uploadProgress = 0,
    this.reviewingIds = const {},
    this.error,
    this.submitError,
  });

  const PaymentsState.initial() : this();

  final List<Payment> items;
  final bool loading;

  /// True while a screenshot is uploading.
  final bool submitting;

  /// 0.0 – 1.0 for the upload progress bar.
  final double uploadProgress;

  /// Payments the guru is verifying/rejecting right now (spinner per row).
  final Set<String> reviewingIds;
  final String? error;

  /// Upload errors, kept apart from list errors so each screen shows its own.
  final String? submitError;

  PaymentsState copyWith({
    List<Payment>? items,
    bool? loading,
    bool? submitting,
    double? uploadProgress,
    Set<String>? reviewingIds,
    String? Function()? error,
    String? Function()? submitError,
  }) =>
      PaymentsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        submitting: submitting ?? this.submitting,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        reviewingIds: reviewingIds ?? this.reviewingIds,
        error: error != null ? error() : this.error,
        submitError: submitError != null ? submitError() : this.submitError,
      );

  @override
  List<Object?> get props => [items, loading, submitting, uploadProgress, reviewingIds, error, submitError];
}
