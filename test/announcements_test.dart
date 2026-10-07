import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/announcement.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/repositories/announcement_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/announcement_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru Amma', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 's1', name: 'Asha', role: UserRole.student, schoolId: 'sc');

class _FakeAnnouncements implements AnnouncementRepository {
  final calls = <String>[];
  Map<String, Object?>? last;

  @override
  Future<List<Announcement>> fetchLatest(String schoolId, {int limit = 20}) async {
    calls.add('fetch');
    return const [];
  }

  @override
  Future<void> create({
    required String schoolId,
    required String title,
    required String body,
    required String authorName,
    bool pinned = false,
  }) async {
    calls.add('create');
    last = {'title': title, 'body': body, 'author': authorName, 'pinned': pinned};
  }

  @override
  Future<void> update({
    required String schoolId,
    required String id,
    required String title,
    required String body,
    required bool pinned,
  }) async {
    calls.add('update:$id');
    last = {'title': title, 'body': body, 'pinned': pinned};
  }

  @override
  Future<void> delete(String schoolId, String id) async => calls.add('delete:$id');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  return store;
}

Announcement _a(String id) => Announcement(id: id, title: 'T', body: 'B', createdAt: DateTime(2026, 10, 1));

void main() {
  late _FakeAnnouncements repo;

  setUp(() {
    repo = _FakeAnnouncements();
    locator.registerSingleton<AnnouncementRepository>(repo);
  });
  tearDown(() => locator.reset());

  test('a student cannot post or delete', () async {
    final store = _store(_student);
    expect(await store.dispatch(saveAnnouncement(title: 'Hi', body: 'There', pinned: false)) as String?, contains('Only'));
    expect(await store.dispatch(deleteAnnouncement(_a('a'))) as String?, contains('Only'));
    expect(repo.calls, isEmpty);
  });

  test('title and message are required and trimmed', () async {
    final store = _store(_guru);
    expect(await store.dispatch(saveAnnouncement(title: '  ', body: 'x', pinned: false)) as String?, contains('title'));
    expect(await store.dispatch(saveAnnouncement(title: 'x', body: ' ', pinned: false)) as String?, contains('Write'));
    expect(
      await store.dispatch(saveAnnouncement(title: 'x' * 101, body: 'x', pinned: false)) as String?,
      contains('title'),
    );
    expect(repo.calls, isEmpty);
    expect(await store.dispatch(saveAnnouncement(title: '  Class off  ', body: ' Friday ', pinned: true)) as String?, isNull);
    expect(repo.last, {'title': 'Class off', 'body': 'Friday', 'author': 'Guru Amma', 'pinned': true});
  });

  test('a new notice is created and an existing one updated, then the list reloads', () async {
    final store = _store(_guru);
    await store.dispatch(saveAnnouncement(title: 'a', body: 'b', pinned: false));
    await store.dispatch(saveAnnouncement(existing: _a('x'), title: 'a2', body: 'b2', pinned: false));
    expect(repo.calls, ['create', 'fetch', 'update:x', 'fetch']);
  });

  test('posting while offline is refused', () async {
    final store = _store(_guru)..dispatch(const SetConnectivityAction(isOnline: false));
    expect(await store.dispatch(saveAnnouncement(title: 'a', body: 'b', pinned: false)) as String?, isNotNull);
    expect(repo.calls, isEmpty);
  });

  test('staff delete a notice', () async {
    final store = _store(_guru);
    expect(await store.dispatch(deleteAnnouncement(_a('x'))) as String?, isNull);
    expect(repo.calls, ['delete:x', 'fetch']);
  });
}
