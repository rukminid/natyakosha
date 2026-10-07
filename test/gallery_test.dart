import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/media_item.dart';
import 'package:natyakosha/data/repositories/media_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/media_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 's1', name: 'Asha', role: UserRole.student, schoolId: 'sc');

MediaItem _m(String id, MediaType type, {String event = 'e1'}) =>
    MediaItem(id: id, eventId: event, type: type, url: 'https://x/$id', uploadedBy: 'g1');

class _FakeMedia implements MediaRepository {
  final uploads = <String>[];
  final deleted = <String>[];
  List<MediaItem> stored = [];
  String? failOn;

  @override
  Future<List<MediaItem>> fetchMedia(String schoolId) async => stored;

  @override
  Future<void> upload({
    required String schoolId,
    required String uploadedBy,
    required String eventId,
    required MediaType type,
    required String localPath,
    String? itemId,
    String? caption,
    void Function(double progress)? onProgress,
  }) async {
    if (localPath == failOn) throw Exception('boom');
    uploads.add('$eventId:${type.name}:$localPath:${itemId ?? '-'}');
    onProgress?.call(1);
  }

  @override
  Future<void> delete(String schoolId, MediaItem item) async => deleted.add(item.id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  return store;
}

void main() {
  group('MediaItem', () {
    test('round trips through a map', () {
      const m = MediaItem(
        id: 'a',
        eventId: 'e1',
        itemId: 'i1',
        type: MediaType.video,
        url: 'https://x/a',
        caption: 'Finale',
        uploadedBy: 'g1',
      );
      expect(MediaItem.fromMap('a', m.toMap()), m);
    });
  });

  group('MediaRepository.contentTypeFor', () {
    test('picks a type from the file extension', () {
      expect(MediaRepository.contentTypeFor(MediaType.video, '/a/b.MOV'), 'video/quicktime');
      expect(MediaRepository.contentTypeFor(MediaType.video, '/a/b'), 'video/mp4');
      expect(MediaRepository.contentTypeFor(MediaType.audio, '/a/b.mp3'), 'audio/mpeg');
      expect(MediaRepository.contentTypeFor(MediaType.audio, '/a/b.m4a'), 'audio/mp4');
      expect(MediaRepository.contentTypeFor(MediaType.photo, '/a/b.png'), 'image/jpeg');
    });
  });

  group('gallery state', () {
    test('loads, fails and clears on sign-out', () {
      var s = appReducer(AppState.initial(), const MediaRequestAction());
      expect(s.media.loading, isTrue);
      s = appReducer(s, MediaLoadedAction([_m('a', MediaType.photo)]));
      expect(s.media.items, hasLength(1));
      s = appReducer(s, const MediaFailureAction('nope'));
      expect(s.media.error, 'nope');
      s = appReducer(s, const SignedOutAction());
      expect(s.media.items, isEmpty);
    });

    test('filterMedia narrows by type and event, keeping order', () {
      final all = [
        _m('a', MediaType.photo),
        _m('b', MediaType.video),
        _m('c', MediaType.photo, event: 'e2'),
      ];
      expect(filterMedia(all).map((m) => m.id), ['a', 'b', 'c']);
      expect(filterMedia(all, type: MediaType.photo).map((m) => m.id), ['a', 'c']);
      expect(filterMedia(all, type: MediaType.photo, eventId: 'e2').map((m) => m.id), ['c']);
    });
  });

  group('gallery thunks', () {
    late _FakeMedia repo;

    setUp(() {
      repo = _FakeMedia();
      locator.registerSingleton<MediaRepository>(repo);
    });
    tearDown(() => locator.reset());

    test('a student cannot upload or delete', () async {
      final store = _store(_student);
      expect(await store.dispatch(uploadMedia(eventId: 'e1', type: MediaType.photo, paths: ['/a.jpg'])) as String?, contains('Only'));
      expect(await store.dispatch(deleteMedia(_m('a', MediaType.photo))) as String?, contains('Only'));
      expect(repo.uploads, isEmpty);
      expect(repo.deleted, isEmpty);
    });

    test('uploads need at least one file and a connection', () async {
      final store = _store(_guru);
      expect(await store.dispatch(uploadMedia(eventId: 'e1', type: MediaType.photo, paths: [])) as String?, contains('at least one'));
      store.dispatch(const SetConnectivityAction(isOnline: false));
      expect(await store.dispatch(uploadMedia(eventId: 'e1', type: MediaType.photo, paths: ['/a.jpg'])) as String?, isNotNull);
      expect(repo.uploads, isEmpty);
    });

    test('every file goes up in order and the gallery reloads', () async {
      repo.stored = [_m('a', MediaType.photo)];
      final store = _store(_guru);
      final progress = <int>[];
      final error = await store.dispatch(uploadMedia(
        eventId: 'e1',
        type: MediaType.photo,
        paths: ['/1.jpg', '/2.jpg'],
        itemId: 'i1',
        onProgress: (done, total, _) => progress.add(done),
      )) as String?;
      expect(error, isNull);
      expect(repo.uploads, ['e1:photo:/1.jpg:i1', 'e1:photo:/2.jpg:i1']);
      expect(progress.last, 2);
      expect(store.state.media.items, hasLength(1));
    });

    test('a failure stops the rest and says how many made it', () async {
      repo.failOn = '/2.jpg';
      final store = _store(_guru);
      final error = await store.dispatch(
        uploadMedia(eventId: 'e1', type: MediaType.photo, paths: ['/1.jpg', '/2.jpg', '/3.jpg']),
      ) as String?;
      expect(error, contains('1 of 3'));
      expect(repo.uploads, ['e1:photo:/1.jpg:-']);
    });

    test('staff delete a file and the gallery reloads', () async {
      final store = _store(_guru);
      expect(await store.dispatch(deleteMedia(_m('a', MediaType.photo))) as String?, isNull);
      expect(repo.deleted, ['a']);
    });
  });
}
