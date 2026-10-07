import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/attendance_record.dart';
import '../../../data/models/attendance_summary.dart';
import '../../../data/models/batch.dart';
import '../../../redux/actions/app_actions.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/attendance_thunks.dart' as att;
import '../../../redux/thunks/batch_thunks.dart' as batch_thunks;
import '../../../redux/thunks/member_thunks.dart' as members;

class AttendanceViewModel extends Equatable {
  const AttendanceViewModel({
    required this.isStaff,
    required this.isOnline,
    required this.students,
    required this.studentsLoading,
    required this.studentsError,
    required this.batches,
    required this.batchId,
    required this.date,
    required this.record,
    required this.loading,
    required this.error,
    required this.month,
    required this.monthLoading,
    required this.monthError,
    required this.saveError,
    required this.loadStudents,
    required this.loadBatches,
    required this.load,
    required this.loadMonth,
    required this.save,
    required this.clearSaveError,
  });

  final bool isStaff;
  final bool isOnline;

  /// The roster: approved students, by name.
  final List<AppUser> students;
  final bool studentsLoading;
  final String? studentsError;

  final List<Batch> batches;

  /// The batch on screen: a batch id, or [AttendanceRecord.allStudents].
  final String batchId;

  /// The day the store has loaded (or is loading).
  final DateTime? date;

  /// Saved attendance for [date]; null when none was taken.
  final AttendanceRecord? record;
  final bool loading;
  final String? error;
  final List<AttendanceRecord> month;
  final bool monthLoading;
  final String? monthError;
  final String? saveError;

  final Future<void> Function() loadStudents;
  final Future<void> Function() loadBatches;
  final Future<void> Function(DateTime date, String batchId) load;
  final Future<void> Function(DateTime month) loadMonth;

  /// Returns an error message, or null when saved.
  final Future<String?> Function(DateTime date, Map<String, bool> marks, String batchId) save;
  final void Function() clearSaveError;

  /// Students of the batch on screen (everyone for "All students").
  List<AppUser> get roster => sel.rosterForBatch(students, batchId);

  /// Class records of the batch on screen.
  List<AttendanceRecord> get batchMonth => sel.recordsForBatch(month, batchId);

  AttendanceSummary get summary => sel.monthlySummary(batchMonth, roster);

  String batchName(String id) {
    if (id == AttendanceRecord.allStudents) return 'All students';
    for (final b in batches) {
      if (b.id == id) return b.name;
    }
    return 'Deleted batch';
  }

  static AttendanceViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    return AttendanceViewModel(
      isStaff: sel.isStaff(s),
      isOnline: s.isOnline,
      students: s.students.items,
      studentsLoading: s.students.loading,
      studentsError: s.students.error,
      batches: s.batches.items,
      batchId: s.attendance.batchId,
      date: s.attendance.date,
      record: s.attendance.record,
      loading: s.attendance.loading,
      error: s.attendance.error,
      month: s.attendance.month,
      monthLoading: s.attendance.monthLoading,
      monthError: s.attendance.monthError,
      saveError: s.attendance.saveError,
      loadStudents: () async => store.dispatch(members.loadStudents()),
      loadBatches: () async => store.dispatch(batch_thunks.loadBatches()),
      load: (date, batchId) async => store.dispatch(att.loadAttendance(date, batchId: batchId)),
      loadMonth: (month) async => store.dispatch(att.loadAttendanceMonth(month.year, month.month)),
      save: (date, marks, batchId) async =>
          await store.dispatch(att.saveAttendance(date, marks, batchId: batchId)) as String?,
      clearSaveError: () => store.dispatch(const ClearAttendanceSaveErrorAction()),
    );
  }

  @override
  List<Object?> get props => [
        isStaff, isOnline, students, studentsLoading, studentsError, batches, batchId, date, record,
        loading, error, month, monthLoading, monthError, saveError,
      ];
}
