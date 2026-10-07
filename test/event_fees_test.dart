import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/event_fee.dart';
import 'package:natyakosha/data/repositories/event_repository.dart';
import 'package:natyakosha/data/services/api_service.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/event_fee_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 's1', name: 'Asha', role: UserRole.student, schoolId: 'sc');
const _parent = AppUser(id: 'p1', name: 'Mum', role: UserRole.parent, schoolId: 'sc', childIds: ['s1', 's2']);

EventFee _fee(String id, EventFeeStatus status, {double amount = 500}) =>
    EventFee(studentId: id, studentName: 'Name $id', eventId: 'e1', amount: amount, status: status);

class _FakeEvents implements EventRepository {
  final calls = <String>[];
  final fees = <String, EventFee>{};
  Map<String, Object?>? lastProof;

  @override
  Future<List<EventFee>> fetchFees(String schoolId, String eventId) async {
    calls.add('fetchFees');
    return fees.values.toList();
  }

  @override
  Future<EventFee?> fetchFee(String schoolId, String eventId, String studentId) async {
    calls.add('fetchFee:$studentId');
    return fees[studentId];
  }

  @override
  Future<void> updateFee({
    required String schoolId,
    required String eventId,
    required String studentId,
    required String markedBy,
    EventFeeStatus? status,
    double? amount,
    dynamic mode,
    String? note,
  }) async =>
      calls.add('update:$studentId:${status?.name}:$amount');

  @override
  Future<void> submitFeeProof({
    required String schoolId,
    required String eventId,
    required String studentId,
    required String screenshotPath,
    String? upiTxnId,
    String? note,
    void Function(double progress)? onProgress,
  }) async {
    calls.add('proof:$studentId');
    lastProof = {'path': screenshotPath, 'txn': upiTxnId};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeApi implements ApiService {
  final reminded = <String>[];

  @override
  Future<void> remindPendingEventFees({required String schoolId, required String eventId}) async =>
      reminded.add('$schoolId/$eventId');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  return store;
}

void main() {
  group('summariseFees', () {
    test('counts paid as collected and leaves waived out of expected', () {
      final s = summariseFees([
        _fee('a', EventFeeStatus.paid),
        _fee('b', EventFeeStatus.pending),
        _fee('c', EventFeeStatus.submitted, amount: 300),
        _fee('d', EventFeeStatus.waived),
      ]);
      expect(s.expected, 1300);
      expect(s.collected, 500);
      expect(s.outstanding, 800);
      expect(s.pendingCount, 1);
      expect(s.submittedCount, 1);
      expect(s.settledCount, 2);
      expect(s.total, 4);
      expect(s.progress, closeTo(500 / 1300, 1e-9));
    });

    test('an empty list is all zero without dividing by zero', () {
      final s = summariseFees(const []);
      expect(s.expected, 0);
      expect(s.progress, 0);
    });
  });

  group('event fees state', () {
    test('kept per event, sorted by name, cleared on sign-out', () {
      var s = appReducer(AppState.initial(), EventFeesLoadedAction('e1', [_fee('b', EventFeeStatus.paid), _fee('a', EventFeeStatus.paid)]));
      expect(feesForEvent(s, 'e1').map((f) => f.studentId), ['a', 'b']);
      expect(feesForEvent(s, 'e2'), isEmpty);
      s = appReducer(s, const EventFeesFailureAction('e1', 'nope'));
      expect(s.eventFees['e1']!.error, 'nope');
      s = appReducer(s, const SignedOutAction());
      expect(s.eventFees, isEmpty);
    });
  });

  group('event fee thunks', () {
    late _FakeEvents repo;
    late _FakeApi api;

    setUp(() {
      repo = _FakeEvents();
      api = _FakeApi();
      locator
        ..registerSingleton<EventRepository>(repo)
        ..registerSingleton<ApiService>(api);
    });
    tearDown(() => locator.reset());

    test('staff load every fee in one query', () async {
      repo.fees['a'] = _fee('a', EventFeeStatus.pending);
      final store = _store(_guru);
      await loadEventFees('e1')(store);
      expect(repo.calls, ['fetchFees']);
      expect(feesForEvent(store.state, 'e1'), hasLength(1));
    });

    test('a student loads only their own fee', () async {
      repo.fees['s1'] = _fee('s1', EventFeeStatus.pending);
      final store = _store(_student);
      await loadEventFees('e1')(store);
      expect(repo.calls, ['fetchFee:s1']);
    });

    test('a parent loads each child fee that exists', () async {
      repo.fees['s2'] = _fee('s2', EventFeeStatus.pending);
      final store = _store(_parent);
      await loadEventFees('e1')(store);
      expect(repo.calls, ['fetchFee:s1', 'fetchFee:s2']);
      expect(feesForEvent(store.state, 'e1').map((f) => f.studentId), ['s2']);
    });

    test('only staff can change a fee', () async {
      final store = _store(_student);
      expect(await store.dispatch(updateEventFee('e1', 's1', status: EventFeeStatus.paid)) as String?, contains('Only'));
      expect(repo.calls, isEmpty);
    });

    test('staff mark a fee paid and the list reloads', () async {
      final store = _store(_guru);
      expect(await store.dispatch(updateEventFee('e1', 's1', status: EventFeeStatus.paid)) as String?, isNull);
      expect(repo.calls, ['update:s1:paid:null', 'fetchFees']);
    });

    test('offline changes are refused', () async {
      final store = _store(_guru)..dispatch(const SetConnectivityAction(isOnline: false));
      expect(await store.dispatch(updateEventFee('e1', 's1', status: EventFeeStatus.paid)) as String?, isNotNull);
      expect(repo.calls, isEmpty);
    });

    test('a student can pay their own fee but not another student fee', () async {
      final store = _store(_student);
      expect(await store.dispatch(submitEventFeeProof('e1', 's1', screenshotPath: '/p.jpg', upiTxnId: '123456789012')) as String?, isNull);
      expect(repo.lastProof, {'path': '/p.jpg', 'txn': '123456789012'});
      expect(await store.dispatch(submitEventFeeProof('e1', 's9', screenshotPath: '/p.jpg')) as String?, contains('own'));
      expect(repo.calls.where((c) => c.startsWith('proof')), ['proof:s1']);
    });

    test('a parent can pay for a child', () async {
      final store = _store(_parent);
      expect(await store.dispatch(submitEventFeeProof('e1', 's2', screenshotPath: '/p.jpg')) as String?, isNull);
    });

    test('reminders go out only for staff and only when someone is pending', () async {
      var store = _store(_student);
      expect(await store.dispatch(remindPendingFees('e1')) as String?, contains('Only'));

      store = _store(_guru)..dispatch(EventFeesLoadedAction('e1', [_fee('a', EventFeeStatus.paid)]));
      expect(await store.dispatch(remindPendingFees('e1')) as String?, contains('Nobody'));
      expect(api.reminded, isEmpty);

      store.dispatch(EventFeesLoadedAction('e1', [_fee('a', EventFeeStatus.pending)]));
      expect(await store.dispatch(remindPendingFees('e1')) as String?, isNull);
      expect(api.reminded, ['sc/e1']);
    });
  });
}
