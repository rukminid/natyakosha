import 'package:redux/redux.dart';

import '../actions/app_actions.dart';
import '../state/attendance_state.dart';

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Whether an answer is for the day and batch now on screen.
bool _current(AttendanceState s, DateTime date, String batchId) => _sameDay(s.date, date) && s.batchId == batchId;

final attendanceReducer = combineReducers<AttendanceState>([
  TypedReducer<AttendanceState, AttendanceRequestAction>(
    (s, a) => s.copyWith(date: a.date, batchId: a.batchId, record: () => null, loading: true, error: () => null),
  ).call,
  // A slow answer for a day the user already left must not overwrite the screen.
  TypedReducer<AttendanceState, AttendanceLoadedAction>(
    (s, a) => _current(s, a.date, a.batchId) ? s.copyWith(record: () => a.record, loading: false) : s,
  ).call,
  TypedReducer<AttendanceState, AttendanceFailureAction>(
    (s, a) => _current(s, a.date, a.batchId) ? s.copyWith(loading: false, error: () => a.message) : s,
  ).call,
  TypedReducer<AttendanceState, AttendanceSavedAction>(_saved).call,
  TypedReducer<AttendanceState, AttendanceSaveFailedAction>(
    (s, a) => s.copyWith(saving: false, saveError: () => a.message),
  ).call,
  TypedReducer<AttendanceState, ClearAttendanceSaveErrorAction>(
    (s, _) => s.copyWith(saveError: () => null),
  ).call,
  TypedReducer<AttendanceState, AttendanceMonthRequestAction>(
    (s, a) => s.copyWith(
      monthStart: DateTime(a.year, a.month),
      month: const [],
      monthLoading: true,
      monthError: () => null,
    ),
  ).call,
  // Ignore a slow answer for a month the user already left.
  TypedReducer<AttendanceState, AttendanceMonthLoadedAction>(
    (s, a) => s.monthStart == DateTime(a.year, a.month)
        ? s.copyWith(month: a.items, monthLoading: false)
        : s,
  ).call,
  TypedReducer<AttendanceState, AttendanceMonthFailureAction>(
    (s, a) => s.copyWith(monthLoading: false, monthError: () => a.message),
  ).call,
  TypedReducer<AttendanceState, MyAttendanceRequestAction>(
    (s, a) => s.copyWith(myMonthStart: DateTime(a.year, a.month), myDays: const {}, myLoading: true, myError: () => null),
  ).call,
  TypedReducer<AttendanceState, MyAttendanceLoadedAction>(
    (s, a) => s.myMonthStart == DateTime(a.year, a.month) ? s.copyWith(myDays: a.days, myLoading: false) : s,
  ).call,
  TypedReducer<AttendanceState, MyAttendanceFailureAction>(
    (s, a) => s.myMonthStart == DateTime(a.year, a.month)
        ? s.copyWith(myLoading: false, myError: () => a.message)
        : s,
  ).call,
]);

/// Shows the saved record straight away (before the server confirms) and
/// keeps the month list in step so the summary is never stale.
AttendanceState _saved(AttendanceState s, AttendanceSavedAction a) {
  final start = s.monthStart;
  final inShownMonth = start != null && a.record.date.year == start.year && a.record.date.month == start.month;
  final month = inShownMonth
      ? ([...s.month.where((r) => r.id != a.record.id), a.record]..sort((x, y) => x.date.compareTo(y.date)))
      : s.month;
  // With no day on screen yet, the saved day becomes the one shown.
  final showIt = s.date == null || _current(s, a.record.date, a.record.batchId);
  return s.copyWith(
    date: showIt ? a.record.date : null,
    batchId: showIt ? a.record.batchId : null,
    record: showIt ? () => a.record : null,
    saving: false,
    saveError: () => null,
    month: month,
  );
}

