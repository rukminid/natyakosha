import 'package:equatable/equatable.dart';

import 'model_utils.dart';
import 'payment.dart' show PaymentMode;

enum EventFeeStatus {
  pending,
  submitted,
  paid,
  waived;

  String get label => switch (this) {
        EventFeeStatus.pending => 'Pending',
        EventFeeStatus.submitted => 'Awaiting check',
        EventFeeStatus.paid => 'Paid',
        EventFeeStatus.waived => 'Waived',
      };

  bool get isSettled => this == EventFeeStatus.paid || this == EventFeeStatus.waived;
}

/// One participant's fee for one event:
/// `schools/{schoolId}/events/{eventId}/fees/{studentId}`.
/// The doc id is the student id, so each student has exactly one fee per event.
class EventFee extends Equatable {
  const EventFee({
    required this.studentId,
    required this.studentName,
    required this.eventId,
    required this.amount,
    required this.status,
    this.mode,
    this.screenshotUrl,
    this.upiTxnId,
    this.note,
    this.markedBy,
    this.paidAt,
  });

  final String studentId;
  final String studentName;
  final String eventId;

  /// Defaults to the event fee; the guru can override per student.
  final double amount;
  final EventFeeStatus status;
  final PaymentMode? mode;
  final String? screenshotUrl;
  final String? upiTxnId;
  final String? note;
  final String? markedBy;
  final DateTime? paidAt;

  factory EventFee.fromMap(String studentId, Map<String, dynamic> map) => EventFee(
        studentId: studentId,
        studentName: map['studentName'] as String? ?? '',
        eventId: map['eventId'] as String? ?? '',
        amount: readDouble(map['amount']),
        status: readEnum(EventFeeStatus.values, map['status'], EventFeeStatus.pending),
        mode: map['mode'] == null ? null : readEnum(PaymentMode.values, map['mode'], PaymentMode.upi),
        screenshotUrl: map['screenshotUrl'] as String?,
        upiTxnId: map['upiTxnId'] as String?,
        note: map['note'] as String?,
        markedBy: map['markedBy'] as String?,
        paidAt: readDate(map['paidAt']),
      );

  Map<String, dynamic> toMap() => {
        'studentName': studentName,
        'eventId': eventId,
        'amount': amount,
        'status': status.name,
        'mode': mode?.name,
        'screenshotUrl': screenshotUrl,
        'upiTxnId': upiTxnId,
        'note': note,
        'markedBy': markedBy,
        'paidAt': writeTimestamp(paidAt),
      };

  @override
  List<Object?> get props => [
        studentId, studentName, eventId, amount, status, mode, screenshotUrl,
        upiTxnId, note, markedBy, paidAt,
      ];
}
