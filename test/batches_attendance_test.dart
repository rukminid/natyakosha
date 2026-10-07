import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/attendance_record.dart';
import 'package:natyakosha/data/models/attendance_summary.dart';
import 'package:natyakosha/data/models/batch.dart';
import 'package:natyakosha/data/repositories/attendance_repository.dart';
import 'package:natyakosha/data/repositories/batch_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/attendance_thunks.dart';
import 'package:natyakosha/redux/thunks/batch_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 's1', name: 'Asha', role: UserRole.student, schoolId: 'sc');
const _parent = AppUser(id: 'p1', name: 'Mum', role: UserRole.parent, schoolId: 'sc', childIds: ['s1', 's2']);

AppUser _s(String id, {String? batch}) =>
    AppUser(id: id, name: 'Name $id', role: UserRole.student, schoolId: 'sc', batchId: batch);

AttendanceRecord _r(DateTime d, Map<String, bool> marks, {String batch = AttendanceRecord.allStudents}) =>
    AttendanceRecord(id: AttendanceRecord.docId(d, batch), batchId: batch, date: d, marks: marks, markedBy: 'g1');

class _FakeAttendance implements AttendanceRepository {
  final saved = <AttendanceRecord>[];
  final fetched = <String>[];
  final days = <String, List<StudentDay>>{};
  AttendanceRecord? toReturn;

  @override
  Future<AttendanceRecord?> fetch(String schoolId, DateTime date,
      [String batchId = AttendanceRecord.allStudents]) async {
    fetched.add(batchId);
    return toReturn;
  }

  @override
  Future<void> save(String schoolId, AttendanceRecord record) async => saved.add(record);

  @override
  Future<List<StudentDay>> fetchStudentMonth(String schoolId, String studentId, int year, int month) async =>
      days[studentId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeBatches implements BatchRepository {
  final calls = <String>[];
  Batch? saved;
  Set<String>? members;
  Set<String>? previous;

  @override
  Future<List<Batch>> fetchAll(String schoolId) async {
    calls.add('fetch');
    return const [];
  }

  @override
  Future<String> save(String schoolId, Batch batch) async {
    calls.add('save');
    saved = batch;
    return 'b';
  }

  @override
  Future<void> delete(String schoolId, String batchId) async => calls.add('delete:$batchId');

  @override
  Future<void> setMembers(String batchId, {required Set<String> memberIds, required Set<String> previousIds}) async {
    calls.add('members:$batchId');
    members = memberIds;
    previous = previousIds;
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
  final mon = DateTime(2026, 10, 5);
  final tue = DateTime(2026, 10, 6);

  group('roster and records per batch', () {
    final students = [_s('a', batch: 'b1'), _s('b', batch: 'b2'), _s('c')];

    test('the whole-school roster is everyone, a batch roster only its students', () {
      expect(rosterForBatch(students, AttendanceRecord.allStudents).map((s) => s.id), ['a', 'b', 'c']);
      expect(rosterForBatch(students, 'b1').map((s) => s.id), ['a']);
      expect(rosterForBatch(students, 'nope'), isEmpty);
    });

    test('recordsForBatch keeps only that batch, or everything for all', () {
      final records = [_r(mon, {'a': true}, batch: 'b1'), _r(mon, {'b': true}, batch: 'b2'), _r(tue, {'c': true})];
      expect(recordsForBatch(records, AttendanceRecord.allStudents), hasLength(3));
      expect(recordsForBatch(records, 'b2').single.batchId, 'b2');
    });
  });

  group('monthlySummary with several batches', () {
    test('a day two batches met counts once, and classes held counts distinct days', () {
      final records = [
        _r(mon, {'a': true}, batch: 'b1'),
        _r(mon, {'b': false}, batch: 'b2'),
        _r(tue, {'a': false}, batch: 'b1'),
      ];
      final summary = monthlySummary(records, [_s('a'), _s('b')]);
      expect(summary.classesHeld, 2);
      final a = summary.students.firstWhere((r) => r.student.id == 'a');
      expect((a.present, a.total), (1, 2));
      final b = summary.students.firstWhere((r) => r.student.id == 'b');
      expect((b.present, b.total), (0, 1));
    });

    test('a student marked in the school sheet and a batch sheet the same day counts once', () {
      final records = [_r(mon, {'a': false}), _r(mon, {'a': true}, batch: 'b1')];
      final a = monthlySummary(records, [_s('a')]).students.single;
      expect((a.present, a.total), (1, 1));
    });
  });

  group('StudentMonth', () {
    test('counts each day once and lists newest first', () {
      final m = StudentMonth(days: [
        StudentDay(date: mon, present: false, batchId: 'b1'),
        StudentDay(date: mon, present: true, batchId: 'b2'),
        StudentDay(date: tue, present: false, batchId: 'b1'),
      ]);
      expect((m.present, m.total, m.absent), (1, 2, 1));
      expect(m.percent, 50);
      expect(m.byDay.map((e) => e.key), [tue, mon]);
    });

    test('no days means zero percent, not a divide by zero', () {
      expect(const StudentMonth(days: []).percent, 0);
    });
  });

  group('attendance state per batch', () {
    test('an answer for another batch is ignored', () {
      var s = appReducer(AppState.initial(), AttendanceRequestAction(mon, batchId: 'b1'));
      expect(s.attendance.batchId, 'b1');
      s = appReducer(s, AttendanceLoadedAction(mon, _r(mon, {'a': true}), batchId: AttendanceRecord.allStudents));
      expect(s.attendance.record, isNull);
      s = appReducer(s, AttendanceLoadedAction(mon, _r(mon, {'a': true}, batch: 'b1'), batchId: 'b1'));
      expect(s.attendance.record, isNotNull);
    });

    test('saving a batch while another is on screen does not replace the screen', () {
      var s = appReducer(AppState.initial(), AttendanceRequestAction(mon, batchId: 'b1'));
      s = appReducer(s, AttendanceSavedAction(_r(mon, {'a': true}, batch: 'b2')));
      expect(s.attendance.record, isNull);
      expect(s.attendance.batchId, 'b1');
    });
  });

  group('attendance thunks with batches', () {
    late _FakeAttendance repo;

    setUp(() {
      repo = _FakeAttendance();
      locator.registerSingleton<AttendanceRepository>(repo);
    });
    tearDown(() => locator.reset());

    test('load asks for the chosen batch', () async {
      final store = _store(_guru);
      await store.dispatch(loadAttendance(mon, batchId: 'b1'));
      expect(repo.fetched, ['b1']);
      expect(store.state.attendance.batchId, 'b1');
    });

    test('saving a batch uses that batch id for the record', () async {
      final store = _store(_guru);
      expect(await store.dispatch(saveAttendance(mon, {'a': true}, batchId: 'b1')) as String?, isNull);
      expect(repo.saved.single.id, '2026-10-05_b1');
      expect(repo.saved.single.batchId, 'b1');
    });

    test('a student loads only their own month; a parent loads each child', () async {
      repo.days['s1'] = [StudentDay(date: mon, present: true, batchId: 'b1')];
      var store = _store(_student);
      await store.dispatch(loadMyAttendance(2026, 10));
      expect(store.state.attendance.myDays.keys, ['s1']);
      expect(store.state.attendance.myDays['s1'], hasLength(1));

      store = _store(_parent);
      await store.dispatch(loadMyAttendance(2026, 10));
      expect(store.state.attendance.myDays.keys, ['s1', 's2']);
    });

    test('a slow answer for a month the student left is ignored', () {
      var s = appReducer(AppState.initial(), const MyAttendanceRequestAction(2026, 10));
      s = appReducer(s, const MyAttendanceRequestAction(2026, 9));
      s = appReducer(s, MyAttendanceLoadedAction(2026, 10, {'s1': [StudentDay(date: mon, present: true, batchId: 'all')]}));
      expect(s.attendance.myDays, isEmpty);
    });
  });

  group('batches', () {
    late _FakeBatches repo;

    setUp(() {
      repo = _FakeBatches();
      locator.registerSingleton<BatchRepository>(repo);
    });
    tearDown(() => locator.reset());

    test('membershipChanges moves only the people who change', () {
      expect(
        BatchRepository.membershipChanges('b1', memberIds: {'a', 'b'}, previousIds: {'b', 'c'}),
        {'a': 'b1', 'c': null},
      );
      expect(BatchRepository.membershipChanges('b1', memberIds: {'a'}, previousIds: {'a'}), isEmpty);
    });

    test('a student cannot manage batches', () async {
      final store = _store(_student);
      expect(await store.dispatch(saveBatch(const Batch(id: '', name: 'X'))) as String?, contains('Only'));
      expect(await store.dispatch(deleteBatch(const Batch(id: 'b', name: 'X'))) as String?, contains('Only'));
      expect(repo.calls, isEmpty);
    });

    test('a name is required and must be unique, ignoring case', () async {
      final store = _store(_guru)..dispatch(const BatchesLoadedAction([Batch(id: 'b1', name: 'Beginners')]));
      expect(await store.dispatch(saveBatch(const Batch(id: '', name: '  '))) as String?, contains('name'));
      expect(await store.dispatch(saveBatch(const Batch(id: '', name: 'beginners'))) as String?, contains('already'));
      expect(await store.dispatch(saveBatch(const Batch(id: 'b1', name: 'BEGINNERS'))) as String?, isNull);
      expect(repo.calls, ['save', 'fetch']);
    });

    test('blank optional fields are stored as null', () async {
      final store = _store(_guru);
      await store.dispatch(saveBatch(const Batch(id: '', name: ' Adv ', level: ' ', timing: ' Sat ')));
      expect(repo.saved!.name, 'Adv');
      expect(repo.saved!.level, isNull);
      expect(repo.saved!.timing, 'Sat');
    });

    test('setting members passes who was in the batch before', () async {
      final store = _store(_guru)
        ..dispatch(StudentsLoadedAction([_s('a', batch: 'b1'), _s('b', batch: 'b2'), _s('c')]));
      expect(await store.dispatch(setBatchMembers(const Batch(id: 'b1', name: 'X'), {'c'})) as String?, isNull);
      expect(repo.previous, {'a'});
      expect(repo.members, {'c'});
    });

    test('offline changes are refused', () async {
      final store = _store(_guru)..dispatch(const SetConnectivityAction(isOnline: false));
      expect(await store.dispatch(saveBatch(const Batch(id: '', name: 'X'))) as String?, isNotNull);
      expect(repo.calls, isEmpty);
    });
  });
}
