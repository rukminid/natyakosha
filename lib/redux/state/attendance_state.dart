import 'package:equatable/equatable.dart';

import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_summary.dart';

/// Attendance for the day being edited, plus the month used by the summary.
class AttendanceState extends Equatable {
  const AttendanceState({
    this.date,
    this.batchId = AttendanceRecord.allStudents,
    this.record,
    this.loading = false,
    this.error,
    this.saving = false,
    this.saveError,
    this.monthStart,
    this.month = const [],
    this.monthLoading = false,
    this.monthError,
    this.myMonthStart,
    this.myDays = const {},
    this.myLoading = false,
    this.myError,
  });

  const AttendanceState.initial() : this();

  /// The day on screen; late answers for another day are ignored.
  final DateTime? date;

  /// The batch being taken: a batch id, or [AttendanceRecord.allStudents].
  final String batchId;

  /// Saved attendance for [date], or null when none was taken yet.
  final AttendanceRecord? record;
  final bool loading;
  final String? error;
  final bool saving;
  final String? saveError;

  /// First day of the month the summary shows (what [month] holds).
  final DateTime? monthStart;

  /// Class days of that month, oldest first.
  final List<AttendanceRecord> month;
  final bool monthLoading;
  final String? monthError;

  /// Student / parent view: first day of the month held in [myDays].
  final DateTime? myMonthStart;

  /// That month's class days for the signed-in student (or each child), by student id.
  final Map<String, List<StudentDay>> myDays;
  final bool myLoading;
  final String? myError;

  /// Pass `record: () => null`, `error: () => null`, … to clear a field.
  AttendanceState copyWith({
    DateTime? date,
    String? batchId,
    AttendanceRecord? Function()? record,
    bool? loading,
    String? Function()? error,
    bool? saving,
    String? Function()? saveError,
    DateTime? monthStart,
    List<AttendanceRecord>? month,
    bool? monthLoading,
    String? Function()? monthError,
    DateTime? myMonthStart,
    Map<String, List<StudentDay>>? myDays,
    bool? myLoading,
    String? Function()? myError,
  }) =>
      AttendanceState(
        date: date ?? this.date,
        batchId: batchId ?? this.batchId,
        record: record != null ? record() : this.record,
        loading: loading ?? this.loading,
        error: error != null ? error() : this.error,
        saving: saving ?? this.saving,
        saveError: saveError != null ? saveError() : this.saveError,
        monthStart: monthStart ?? this.monthStart,
        month: month ?? this.month,
        monthLoading: monthLoading ?? this.monthLoading,
        monthError: monthError != null ? monthError() : this.monthError,
        myMonthStart: myMonthStart ?? this.myMonthStart,
        myDays: myDays ?? this.myDays,
        myLoading: myLoading ?? this.myLoading,
        myError: myError != null ? myError() : this.myError,
      );

  @override
  List<Object?> get props =>
      [
        date, batchId, record, loading, error, saving, saveError, monthStart, month, monthLoading, monthError,
        myMonthStart, myDays, myLoading, myError,
      ];
}
