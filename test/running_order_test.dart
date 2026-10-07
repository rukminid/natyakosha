import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/dance_event.dart';
import 'package:natyakosha/data/models/event_item.dart';
import 'package:natyakosha/data/repositories/event_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/event_item_thunks.dart';
import 'package:natyakosha/redux/thunks/event_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc');
const _student = AppUser(id: 'st1', name: 'Student', role: UserRole.student, schoolId: 'sc');

EventItem _item(String id, int order, {List<String> performers = const []}) =>
    EventItem(id: id, order: order, songName: 'Song $id', performerIds: performers);

class _FakeEvents implements EventRepository {
  final calls = <String>[];
  List<EventItem> stored = [];
  List<EventItem>? lastReorder;
  List<EventItem>? lastRemaining;
  Set<String>? removedPerformers;
  bool failReorder = false;

  @override
  Future<List<EventItem>> fetchItems(String schoolId, String eventId) async => stored;

  @override
  Future<String> addItem(String schoolId, String eventId, EventItem item) async {
    calls.add('add');
    return 'new';
  }

  @override
  Future<void> updateItem(String schoolId, String eventId, EventItem item) async => calls.add('update');

  @override
  Future<void> deleteItem(String s, String e, String itemId, List<EventItem> remaining) async {
    calls.add('delete:$itemId');
    lastRemaining = remaining;
  }

  @override
  Future<void> reorderItems(String schoolId, String eventId, List<EventItem> items) async {
    calls.add('reorder');
    if (failReorder) throw Exception('boom');
    lastReorder = items;
  }

  @override
  Future<void> removePerformers(String schoolId, String eventId, Set<String> dancerIds) async =>
      removedPerformers = dancerIds;

  @override
  Future<void> updateEvent({
    required String schoolId,
    required DanceEvent event,
    required List<AppUser> participants,
  }) async =>
      calls.add('updateEvent');

  @override
  Future<List<DanceEvent>> fetchEvents(String schoolId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  return store;
}

void main() {
  group('EventItem', () {
    test('toMap / fromMap round trip keeps performers', () {
      final item = _item('a', 2, performers: ['x', 'y']).copyWith(raga: 'Nattai', durationMinutes: 6);
      final back = EventItem.fromMap('a', item.toMap());
      expect(back, item);
    });

    test('copyWith changes order only when asked', () {
      final item = _item('a', 2);
      expect(item.copyWith(order: 5).order, 5);
      expect(item.copyWith(songName: 'New').order, 2);
    });
  });

  group('running order state', () {
    test('items are kept per event and sorted by order', () {
      var s = AppState.initial();
      s = appReducer(s, EventItemsLoadedAction('e1', [_item('b', 2), _item('a', 1)]));
      s = appReducer(s, EventItemsLoadedAction('e2', [_item('c', 1)]));
      expect(itemsForEvent(s, 'e1').map((i) => i.id), ['a', 'b']);
      expect(itemsForEvent(s, 'e2').map((i) => i.id), ['c']);
      expect(itemsForEvent(s, 'none'), isEmpty);
    });

    test('request and failure set loading and error', () {
      var s = appReducer(AppState.initial(), const EventItemsRequestAction('e1'));
      expect(s.eventItems['e1']!.loading, isTrue);
      s = appReducer(s, const EventItemsFailureAction('e1', 'nope'));
      expect(s.eventItems['e1']!.loading, isFalse);
      expect(s.eventItems['e1']!.error, 'nope');
    });

    test('signing out clears them', () {
      var s = appReducer(AppState.initial(), EventItemsLoadedAction('e1', [_item('a', 1)]));
      s = appReducer(s, const SignedOutAction());
      expect(s.eventItems, isEmpty);
    });
  });

  group('running order thunks', () {
    late _FakeEvents repo;

    setUp(() {
      repo = _FakeEvents();
      locator.registerSingleton<EventRepository>(repo);
    });
    tearDown(() => locator.reset());

    test('a student cannot edit the running order', () async {
      final store = _store(_student);
      expect(await store.dispatch(saveEventItem('e1', _item('', 0))) as String?, contains('Only'));
      expect(await store.dispatch(reorderEventItems('e1', [_item('a', 1)])) as String?, contains('Only'));
      expect(repo.calls, isEmpty);
    });

    test('offline edits are refused', () async {
      final store = _store(_guru)..dispatch(const SetConnectivityAction(isOnline: false));
      expect(await store.dispatch(saveEventItem('e1', _item('', 0))) as String?, isNotNull);
      expect(repo.calls, isEmpty);
    });

    test('a new song is added, an existing one updated', () async {
      final store = _store(_guru);
      expect(await store.dispatch(saveEventItem('e1', _item('', 0))) as String?, isNull);
      expect(await store.dispatch(saveEventItem('e1', _item('a', 1))) as String?, isNull);
      expect(repo.calls, ['add', 'update']);
    });

    test('reorder shows the new order at once and saves it numbered 1..n', () async {
      final store = _store(_guru)
        ..dispatch(EventItemsLoadedAction('e1', [_item('a', 1), _item('b', 2), _item('c', 3)]));
      final error =
          await store.dispatch(reorderEventItems('e1', [_item('c', 3), _item('a', 1), _item('b', 2)])) as String?;
      expect(error, isNull);
      expect(itemsForEvent(store.state, 'e1').map((i) => i.id), ['c', 'a', 'b']);
      expect(repo.lastReorder!.map((i) => i.order), [1, 2, 3]);
    });

    test('a failed reorder reloads the saved order and reports the error', () async {
      repo
        ..failReorder = true
        ..stored = [_item('a', 1), _item('b', 2)];
      final store = _store(_guru)..dispatch(EventItemsLoadedAction('e1', repo.stored));
      final error = await store.dispatch(reorderEventItems('e1', [_item('b', 2), _item('a', 1)])) as String?;
      expect(error, isNotNull);
      expect(itemsForEvent(store.state, 'e1').map((i) => i.id), ['a', 'b']);
    });

    test('deleting a song renumbers the rest', () async {
      repo.stored = [_item('a', 1), _item('c', 2)];
      final store = _store(_guru)
        ..dispatch(EventItemsLoadedAction('e1', [_item('a', 1), _item('b', 2), _item('c', 3)]));
      expect(await store.dispatch(deleteEventItem('e1', _item('b', 2))) as String?, isNull);
      expect(repo.calls, ['delete:b']);
      expect(repo.lastRemaining!.map((i) => i.id), ['a', 'c']);
    });

    test('taking a dancer off the event removes them from the songs', () async {
      final store = _store(_guru)
        ..dispatch(EventsLoadedAction([
          DanceEvent(
            id: 'e1',
            title: 'Show',
            date: DateTime(2026, 11, 1),
            venue: 'Hall',
            participantIds: const ['x', 'y'],
          ),
        ]));
      final edited = DanceEvent(
        id: 'e1',
        title: 'Show',
        date: DateTime(2026, 11, 1),
        venue: 'Hall',
        participantIds: const ['x'],
      );
      const x = AppUser(id: 'x', name: 'X', role: UserRole.student, schoolId: 'sc');
      expect(await store.dispatch(saveEvent(edited, const [x])) as String?, isNull);
      expect(repo.removedPerformers, {'y'});
    });
  });
}
