import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/theory_note.dart';
import 'package:natyakosha/data/repositories/theory_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/theory_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 's1', name: 'Asha', role: UserRole.student, schoolId: 'sc');

TheoryNote _n(String id, String topic, String title, {String body = 'text', String? level, List<String> images = const []}) =>
    TheoryNote(id: id, topic: topic, title: title, body: body, level: level, imageUrls: images);

class _FakeTheory implements TheoryRepository {
  final calls = <String>[];
  TheoryNote? saved;
  List<String>? newPaths;
  List<String>? removed;
  List<TheoryNote> stored = [];

  @override
  Future<List<TheoryNote>> fetchAll(String schoolId) async {
    calls.add('fetch');
    return stored;
  }

  @override
  Future<String> save({
    required String schoolId,
    required TheoryNote note,
    List<String> newImagePaths = const [],
    List<String> removedUrls = const [],
    void Function(double progress)? onProgress,
  }) async {
    calls.add('save');
    saved = note;
    newPaths = newImagePaths;
    removed = removedUrls;
    return 'id';
  }

  @override
  Future<void> delete(String schoolId, TheoryNote note) async => calls.add('delete:${note.id}');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  return store;
}

void main() {
  group('TheoryNote', () {
    test('survives the cache and Firestore maps', () {
      final n = _n('a', 'Hastas', 'Pataka', level: 'Beginner', images: ['u1', 'u2']);
      expect(TheoryNote.fromJson(n.toJson()), n);
      expect(TheoryNote.fromMap('a', n.toMap()).imageUrls, ['u1', 'u2']);
    });

    test('copyWith can clear the level', () {
      expect(_n('a', 't', 'x', level: 'Advanced').copyWith(clearLevel: true).level, isNull);
      expect(_n('a', 't', 'x', level: 'Advanced').copyWith(title: 'y').level, 'Advanced');
    });
  });

  group('sorting and filtering', () {
    final notes = [
      _n('1', 'Talas', 'Adi tala', body: 'Eight beats'),
      _n('2', 'hastas', 'Pataka', level: 'Beginner'),
      _n('3', 'Hastas', 'Alapadma', level: 'Advanced'),
    ];

    test('sortNotes goes by topic then title, ignoring case', () {
      expect(TheoryRepository.sortNotes(notes).map((n) => n.id), ['3', '2', '1']);
    });

    test('filterTheory searches title, topic and body', () {
      expect(filterTheory(notes, query: 'EIGHT').map((n) => n.id), ['1']);
      expect(filterTheory(notes, query: 'pata').map((n) => n.id), ['2']);
      expect(filterTheory(notes, query: 'tala').map((n) => n.id), ['1']);
    });

    test('filterTheory narrows by topic and level', () {
      expect(filterTheory(notes, topic: 'Hastas').map((n) => n.id), ['3']);
      expect(filterTheory(notes, level: 'Beginner').map((n) => n.id), ['2']);
    });

    test('theoryTopics lists each topic once', () {
      expect(theoryTopics(notes), ['hastas', 'Hastas', 'Talas']);
    });
  });

  group('theory state', () {
    test('loads, fails and clears on sign-out', () {
      var s = appReducer(AppState.initial(), const TheoryRequestAction());
      expect(s.theory.loading, isTrue);
      s = appReducer(s, TheoryLoadedAction([_n('a', 't', 'x')]));
      expect(theoryById(s, 'a'), isNotNull);
      expect(theoryById(s, 'zzz'), isNull);
      s = appReducer(s, const TheoryFailureAction('nope'));
      expect(s.theory.error, 'nope');
      s = appReducer(s, const SignedOutAction());
      expect(s.theory.items, isEmpty);
    });
  });

  group('theory thunks', () {
    late _FakeTheory repo;

    setUp(() {
      repo = _FakeTheory();
      locator.registerSingleton<TheoryRepository>(repo);
    });
    tearDown(() => locator.reset());

    test('a student cannot save or delete', () async {
      final store = _store(_student);
      expect(await store.dispatch(saveTheoryNote(_n('', 't', 'x'))) as String?, contains('Only'));
      expect(await store.dispatch(deleteTheoryNote(_n('a', 't', 'x'))) as String?, contains('Only'));
      expect(repo.calls, isEmpty);
    });

    test('topic, title and some content are required', () async {
      final store = _store(_guru);
      expect(await store.dispatch(saveTheoryNote(_n('', ' ', 'x'))) as String?, contains('topic'));
      expect(await store.dispatch(saveTheoryNote(_n('', 't', ' '))) as String?, contains('title'));
      expect(await store.dispatch(saveTheoryNote(_n('', 't', 'x', body: ' '))) as String?, contains('Write'));
      expect(repo.calls, isEmpty);
    });

    test('a note with only pictures is allowed, and text is trimmed', () async {
      final store = _store(_guru);
      expect(
        await store.dispatch(saveTheoryNote(_n('', ' Hastas ', ' Pataka ', body: ' '), newImagePaths: ['/a.jpg'])) as String?,
        isNull,
      );
      expect(repo.saved!.topic, 'Hastas');
      expect(repo.saved!.title, 'Pataka');
      expect(repo.newPaths, ['/a.jpg']);
      expect(repo.calls, ['save', 'fetch']);
    });

    test('removing the last picture of an empty-text note is refused', () async {
      final store = _store(_guru);
      final note = _n('a', 't', 'x', body: '', images: ['u1']);
      expect(await store.dispatch(saveTheoryNote(note, removedUrls: ['u1'])) as String?, contains('Write'));
    });

    test('at most six pictures', () async {
      final store = _store(_guru);
      final note = _n('a', 't', 'x', images: ['1', '2', '3', '4']);
      expect(await store.dispatch(saveTheoryNote(note, newImagePaths: ['a', 'b', 'c'])) as String?, contains('6'));
      expect(await store.dispatch(saveTheoryNote(note, newImagePaths: ['a', 'b'])) as String?, isNull);
      expect(await store.dispatch(saveTheoryNote(note, newImagePaths: ['a', 'b', 'c'], removedUrls: ['1'])) as String?, isNull);
    });

    test('saving while offline is refused', () async {
      final store = _store(_guru)..dispatch(const SetConnectivityAction(isOnline: false));
      expect(await store.dispatch(saveTheoryNote(_n('', 't', 'x'))) as String?, isNotNull);
      expect(repo.calls, isEmpty);
    });

    test('delete removes the note and reloads', () async {
      final store = _store(_guru);
      expect(await store.dispatch(deleteTheoryNote(_n('a', 't', 'x'))) as String?, isNull);
      expect(repo.calls, ['delete:a', 'fetch']);
    });
  });
}
