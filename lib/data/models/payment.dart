import 'package:equatable/equatable.dart';

import 'model_utils.dart';

enum PaymentStatus {
  /// Due, nothing uploaded yet.
  pending,

  /// Student uploaded a screenshot; guru has not checked it yet.
  submitted,

  /// Guru confirmed the money arrived.
  verified,

  /// Guru could not match the payment; student should re-upload.
  rejected;

  String get label => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.submitted => 'Awaiting check',
        PaymentStatus.verified => 'Paid',
        PaymentStatus.rejected => 'Rejected',
      };
}

enum PaymentMode { upi, cash, bank, other }

/// Monthly fee payment: `schools/{schoolId}/payments/{paymentId}`.
class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.month,
    required this.amount,
    required this.status,
    this.mode = PaymentMode.upi,
    this.upiTxnId,
    this.screenshotUrl,
    this.note,
    this.verifiedBy,
    this.submittedAt,
    this.verifiedAt,
  });

  final String id;
  final String studentId;
  final String studentName;

  /// Billing month as `yyyy-MM`, e.g. `2026-10`.
  final String month;
  final double amount;
  final PaymentStatus status;
  final PaymentMode mode;
  final String? upiTxnId;
  final String? screenshotUrl;
  final String? note;
  final String? verifiedBy;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  factory Payment.fromMap(String id, Map<String, dynamic> map) => Payment(
        id: id,
        studentId: map['studentId'] as String? ?? '',
        studentName: map['studentName'] as String? ?? '',
        month: map['month'] as String? ?? '',
        amount: readDouble(map['amount']),
        status: readEnum(PaymentStatus.values, map['status'], PaymentStatus.pending),
        mode: readEnum(PaymentMode.values, map['mode'], PaymentMode.upi),
        upiTxnId: map['upiTxnId'] as String?,
        screenshotUrl: map['screenshotUrl'] as String?,
        note: map['note'] as String?,
        verifiedBy: map['verifiedBy'] as String?,
        submittedAt: readDate(map['submittedAt']),
        verifiedAt: readDate(map['verifiedAt']),
      );

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'month': month,
        'amount': amount,
        'status': status.name,
        'mode': mode.name,
        'upiTxnId': upiTxnId,
        'screenshotUrl': screenshotUrl,
        'note': note,
        'verifiedBy': verifiedBy,
        'submittedAt': writeTimestamp(submittedAt),
        'verifiedAt': writeTimestamp(verifiedAt),
      };

  Payment copyWith({PaymentStatus? status, String? verifiedBy, DateTime? verifiedAt, String? note}) =>
      Payment(
        id: id,
        studentId: studentId,
        studentName: studentName,
        month: month,
        amount: amount,
        status: status ?? this.status,
        mode: mode,
        upiTxnId: upiTxnId,
        screenshotUrl: screenshotUrl,
        note: note ?? this.note,
        verifiedBy: verifiedBy ?? this.verifiedBy,
        submittedAt: submittedAt,
        verifiedAt: verifiedAt ?? this.verifiedAt,
      );

  @override
  List<Object?> get props => [
        id, studentId, studentName, month, amount, status, mode, upiTxnId,
        screenshotUrl, note, verifiedBy, submittedAt, verifiedAt,
      ];
}
