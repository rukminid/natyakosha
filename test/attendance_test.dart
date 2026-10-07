import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/attendance_record.dart';
import 'package:natyakosha/data/repositories/attendance_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/attendance_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 'st1', name: 'Ananya', role: UserRole.student, schoolId: 'sc');

AppUser _s(String id, String name) => AppUser(id: id, name: name, role: UserRole.student, schoolId: 'sc');

AttendanceRecord _record(DateTime date, Map<String, bool> marks) => AttendanceRecord(
      id: AttendanceRecord.docId(date),
      batchId: AttendanceRecord.allStudents,
      date: date,
      marks: marks,
      markedBy: 'g1',
    );

class _FakeRepo implements AttendanceRepository {
  final saved = <AttendanceRecord>[];
  Completer<void>? pendingSave;
  Object? saveError;

  @override
  Future<void> save(String schoolId, AttendanceRecord record) async {
    saved.add(record);
    if (saveError != null) throw saveError!;
    await pendingSave?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  return store;
}

void main() {
  group('AttendanceRecord', () {
    test('docId is the date plus the batch', () {
      expect(AttendanceRecord.docId(DateTime(2026, 10, 5)), '2026-10-05_all');
      expect(AttendanceRecord.docId(DateTime(2026, 1, 31), 'b1'), '2026-01-31_b1');
    });

    test('counts present and absent from the marks', () {
      final r = _record(DateTime(2026, 10, 5), {'a': true, 'b': false, 'c': true});
      expect(r.presentCount, 2);
      expect(r.absentCount, 1);
      expect(r.presentIds, ['a', 'c']);
      expect(r.absentIds, ['b']);
      expect(r.isPresent('b'), isFalse);
      expect(r.isPresent('zzz'), isNull);
    });

    test('survives a toMap / fromMap round trip', () {
      final r = _record(DateTime(2026, 10, 5), {'a': true, 'b': false});
      final back = AttendanceRecord.fromMap(r.id, r.toMap());
      expect(back.marks, r.marks);
      expect(back.date, r.date);
      expect(back.markedBy, 'g1');
    });

    test('reads an older record that only listed who was present', () {
      final r = AttendanceRecord.fromMap('2026-10-05_all', {
        'batchId': 'all',
        'presentIds': ['a', 'b'],
        'markedBy': 'g1',
      });
      expect(r.marks, {'a': true, 'b': true});
    });

    test('dayOf drops the time of day', () {
      expect(AttendanceRecord.dayOf(DateTime(2026, 10, 5, 17, 30)), DateTime(2026, 10, 5));
    });
  });

  group('attendance reducer', () {
    final today = DateTime(2026, 10, 5);
    final other = DateTime(2026, 10, 6);

    test('requesting a day clears the old record and starts loading', () {
      var s = appReducer(AppState.initial(), AttendanceLoadedAction(today, null));
      s = appReducer(s, AttendanceRequestAction(today));
      s = appReducer(s, AttendanceLoadedAction(today, _record(today, {'a': true})));
      s = appReducer(s, AttendanceRequestAction(other));
      expect(s.attendance.record, isNull);
      expect(s.attendance.loading, isTrue);
      expect(s.attendance.date, other);
    });

    test('a late answer for a day the user left is ignored', () {
      var s = appReducer(AppState.initial(), AttendanceRequestAction(today));
      s = appReducer(s, AttendanceRequestAction(other));
      s = appReducer(s, AttendanceLoadedAction(today, _record(today, {'a': true})));
      expect(s.attendance.record, isNull);
      expect(s.attendance.loading, isTrue);
    });

    test('saving shows the record at once and keeps the month list in step', () {
      var s = appReducer(AppState.initial(), const AttendanceMonthRequestAction(2026, 10));
      s = appReducer(s, AttendanceMonthLoadedAction(2026, 10, [_record(DateTime(2026, 10, 1), {'a': true})]));
      s = appReducer(s, AttendanceRequestAction(today));
      s = appReducer(s, AttendanceSavedAction(_record(today, {'a': false})));
      expect(s.attendance.record?.marks, {'a': false});
      expect(s.attendance.month.map((r) => r.date.day), [1, 5]);

      // Saving the same day again replaces it instead of duplicating.
      s = appReducer(s, AttendanceSavedAction(_record(today, {'a': true})));
      expect(s.attendance.month.length, 2);
      expect(s.attendance.month.last.marks, {'a': true});
    });

    test('a record from another month does not enter the shown month', () {
      var s = appReducer(AppState.initial(), const AttendanceMonthRequestAction(2026, 10));
      s = appReducer(s, const AttendanceMonthLoadedAction(2026, 10, []));
      s = appReducer(s, AttendanceSavedAction(_record(DateTime(2026, 9, 28), {'a': true})));
      expect(s.attendance.month, isEmpty);
    });

    test('a slow month answer for a month the user left is ignored', () {
      var s = appReducer(AppState.initial(), const AttendanceMonthRequestAction(2026, 9));
      s = appReducer(s, const AttendanceMonthRequestAction(2026, 10));
      s = appReducer(s, AttendanceMonthLoadedAction(2026, 9, [_record(DateTime(2026, 9, 3), {'a': true})]));
      expect(s.attendance.month, isEmpty);
      expect(s.attendance.monthLoading, isTrue);
    });

    test('signing out clears attendance', () {
      var s = appReducer(AppState.initial(), AttendanceSavedAction(_record(today, {'a': true})));
      s = appReducer(s, const SignedOutAction());
      expect(s.attendance.record, isNull);
      expect(s.attendance.month, isEmpty);
    });
  });

  group('monthlySummary', () {
    test('counts present days out of the days each student was on the roster', () {
      final records = [
        _record(DateTime(2026, 10, 1), {'a': true, 'b': false}),
        _record(DateTime(2026, 10, 2), {'a': true, 'b': true}),
        _record(DateTime(2026, 10, 3), {'a': false, 'b': true, 'late': true}),
        _record(DateTime(2026, 10, 4), {'a': true, 'b': true, 'late': false}),
      ];
      final summary = monthlySummary(records, [_s('a', 'A'), _s('b', 'B'), _s('late', 'Late')]);
      final byId = {for (final r in summary.students) r.student.id: r};

      expect(summary.classesHeld, 4);
      expect(byId['a']!.present, 3);
      expect(byId['a']!.total, 4);
      expect(byId['a']!.percent, 75);
      expect(byId['b']!.percent, 75);
      // Joined on day 3: only counted from then, never absent before.
      expect(byId['late']!.total, 2);
      expect(byId['late']!.percent, 50);
      expect(summary.averagePercent, closeTo((75 + 75 + 50) / 3, 0.001));
    });

    test('a student with no class days has 0% and does not drag the average', () {
      final summary = monthlySummary(
        [_record(DateTime(2026, 10, 1), {'a': true})],
        [_s('a', 'A'), _s('new', 'New')],
      );
      expect(summary.students.last.total, 0);
      expect(summary.students.last.percent, 0);
      expect(summary.averagePercent, 100);
    });

    test('no records means nothing held and a 0 average', () {
      final summary = monthlySummary(const [], [_s('a', 'A')]);
      expect(summary.classesHeld, 0);
      expect(summary.averagePercent, 0);
    });
  });

  group('saveAttendance', () {
    late _FakeRepo repo;
    final today = AttendanceRecord.dayOf(DateTime.now());

    setUp(() {
      repo = _FakeRepo();
      locator.registerSingleton<AttendanceRepository>(repo);
    });
    tearDown(() => locator.reset());

    test('a student cannot take attendance', () async {
      final store = _store(_student);
      final error = await store.dispatch(saveAttendance(today, {'a': true})) as String?;
      expect(error, contains('Only'));
      expect(repo.saved, isEmpty);
    });

    test('a future date is refused', () async {
      final store = _store(_guru);
      final error = await store.dispatch(saveAttendance(today.add(const Duration(days: 1)), {'a': true})) as String?;
      expect(error, contains('future'));
      expect(repo.saved, isEmpty);
    });

    test('saves without waiting for the server (works offline)', () async {
      repo.pendingSave = Completer<void>(); // the server never answers
      final store = _store(_guru);
      final error = await store.dispatch(saveAttendance(today, {'a': true, 'b': false})) as String?;

      expect(error, isNull); // returned although the write has not finished
      expect(store.state.attendance.record?.marks, {'a': true, 'b': false});
      expect(repo.saved.single.markedBy, 'g1');
      expect(repo.saved.single.id, AttendanceRecord.docId(today));
    });

    test('keeps marks of people no longer on the roster', () async {
      final store = _store(_guru);
      store.dispatch(AttendanceRequestAction(today));
      store.dispatch(AttendanceLoadedAction(today, _record(today, {'gone': false, 'a': true})));
      await store.dispatch(saveAttendance(today, {'a': false}));
      expect(repo.saved.single.marks, {'gone': false, 'a': false});
    });

    test('a rejected write is reported as a save error', () async {
      repo.saveError = StateError('permission denied');
      final store = _store(_guru);
      await store.dispatch(saveAttendance(today, {'a': true}));
      await Future<void>.delayed(Duration.zero);
      expect(store.state.attendance.saveError, isNotNull);
    });
  });
}
