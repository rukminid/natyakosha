import 'dart:async';

import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_summary.dart';
import '../../data/repositories/attendance_repository.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';
import 'event_fee_thunks.dart' show feeStudentIds;

AttendanceRepository get _repo => locator<AttendanceRepository>();

/// Loads what was saved for [date] and [batchId] (null in the store when
/// nothing was).
AppThunk loadAttendance(DateTime date, {String batchId = AttendanceRecord.allStudents}) =>
    (Store<AppState> store) async {
      final user = store.state.auth.user;
      final day = AttendanceRecord.dayOf(date);
      if (user == null || !user.role.isStaff || !store.state.firebaseReady) return;
      store.dispatch(AttendanceRequestAction(day, batchId: batchId));
      try {
        store.dispatch(AttendanceLoadedAction(day, await _repo.fetch(user.schoolId, day, batchId), batchId: batchId));
      } catch (e) {
        store.dispatch(AttendanceFailureAction(day, AppException.from(e).message, batchId: batchId));
      }
    };

/// A student's (or a parent's children's) class days for one month.
AppThunk loadMyAttendance(int year, int month) => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.isApproved || !store.state.firebaseReady) return;
      store.dispatch(MyAttendanceRequestAction(year, month));
      try {
        final days = <String, List<StudentDay>>{};
        for (final id in feeStudentIds(user)) {
          days[id] = await _repo.fetchStudentMonth(user.schoolId, id, year, month);
        }
        store.dispatch(MyAttendanceLoadedAction(year, month, days));
      } catch (e) {
        store.dispatch(MyAttendanceFailureAction(year, month, AppException.from(e).message));
      }
    };

/// Class days of one month, for the summary.
AppThunk loadAttendanceMonth(int year, int month) => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.role.isStaff || !store.state.firebaseReady) return;
      store.dispatch(AttendanceMonthRequestAction(year, month));
      try {
        store.dispatch(AttendanceMonthLoadedAction(
          year,
          month,
          await _repo.fetchMonth(user.schoolId, year, month),
        ));
      } catch (e) {
        store.dispatch(AttendanceMonthFailureAction(AppException.from(e).message));
      }
    };

/// Saves [marks] (studentId → present?) for [date].
///
/// Works offline: the screen updates at once and Firestore sends the write
/// when the phone is back online, so this never waits for the server. A
/// rejected write shows up later as `attendance.saveError`.
/// Returns an error message when the user may not save, otherwise null.
Future<String?> Function(Store<AppState>) saveAttendance(
  DateTime date,
  Map<String, bool> marks, {
  String batchId = AttendanceRecord.allStudents,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return 'Only your guru or teachers can take attendance.';
      final day = AttendanceRecord.dayOf(date);
      if (day.isAfter(AttendanceRecord.dayOf(DateTime.now()))) {
        return 'You cannot take attendance for a future date.';
      }

      // Keep marks of people no longer on the roster so editing never erases history.
      final saved = store.state.attendance.record;
      final keptMarks = saved != null && AttendanceRecord.dayOf(saved.date) == day && saved.batchId == batchId
          ? {...saved.marks, ...marks}
          : {...marks};
      final record = AttendanceRecord(
        id: AttendanceRecord.docId(day, batchId),
        batchId: batchId,
        date: day,
        marks: keptMarks,
        markedBy: me.id,
      );

      store.dispatch(AttendanceSavedAction(record));
      unawaited(_repo
          .save(me.schoolId, record)
          .catchError((Object e) => store.dispatch(AttendanceSaveFailedAction(AppException.from(e).message))));
      return null;
    };
