import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/chat.dart';
import 'package:natyakosha/data/models/chat_message.dart';
import 'package:natyakosha/data/models/member.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/chat_thunks.dart';
import 'package:redux/redux.dart';

Member _m(String id, String name, {int? month, int? day, UserRole role = UserRole.student}) =>
    Member(id: id, name: name, role: role, birthMonth: month, birthDay: day);

Store<AppState> _store(AppUser user, {List<Member> directory = const []}) {
  final store = Store<AppState>(
    appReducer,
    initialState: AppState.initial(),
    middleware: [thunkMiddleware],
  );
  store.dispatch(AuthSuccessAction(user));
  store.dispatch(DirectoryLoadedAction(directory));
  return store;
}

void main() {
  group('Member birthdays', () {
    test('birthdayIn returns the date in the given year', () {
      expect(_m('a', 'A', month: 10, day: 12).birthdayIn(2026), DateTime(2026, 10, 12));
    });

    test('no birthday set means no date', () {
      expect(_m('a', 'A').birthdayIn(2026), isNull);
      expect(_m('a', 'A').hasBirthdayOn(DateTime(2026, 10, 12)), isFalse);
    });

    test('29 Feb is celebrated on 28 Feb in a non-leap year', () {
      final leapling = _m('a', 'A', month: 2, day: 29);
      expect(leapling.birthdayIn(2027), DateTime(2027, 2, 28));
      expect(leapling.hasBirthdayOn(DateTime(2027, 2, 28)), isTrue);
      expect(leapling.hasBirthdayOn(DateTime(2027, 3, 1)), isFalse);
    });

    test('29 Feb stays on 29 Feb in a leap year', () {
      final leapling = _m('a', 'A', month: 2, day: 29);
      expect(leapling.birthdayIn(2028), DateTime(2028, 2, 29));
      expect(leapling.hasBirthdayOn(DateTime(2028, 2, 28)), isFalse);
    });

    test('fromUser keeps only day and month of the date of birth', () {
      final m = Member.fromUser(AppUser(
        id: 'u',
        name: 'Ananya',
        role: UserRole.student,
        schoolId: 's',
        dob: DateTime(2012, 3, 9),
      ));
      expect(m.birthMonth, 3);
      expect(m.birthDay, 9);
      expect(m.toMap().containsKey('dob'), isFalse);
      expect(m.toMap().values.whereType<DateTime>(), isEmpty);
    });
  });

  group('birthday selectors', () {
    final members = [
      _m('1', 'Meera', month: 10, day: 20),
      _m('2', 'Ananya', month: 10, day: 5),
      _m('3', 'Divya', month: 10, day: 5),
      _m('4', 'Kavya', month: 11, day: 1),
      _m('5', 'NoDate'),
    ];

    test('birthdaysOn lists that day by name', () {
      expect(birthdaysOn(members, DateTime(2026, 10, 5)).map((m) => m.name), ['Ananya', 'Divya']);
    });

    test('birthdaysInMonth is ordered by day then name and skips other months', () {
      final board = birthdaysInMonth(members, 2026, 10);
      expect(board.map((m) => m.name), ['Ananya', 'Divya', 'Meera']);
    });
  });

  group('Chat', () {
    test('directId is the same whichever person starts the chat', () {
      expect(Chat.directId('b', 'a'), Chat.directId('a', 'b'));
      expect(Chat.directId('a', 'b'), 'a_b');
    });

    test('titleFor shows the group name or the other person', () {
      final dir = {'g': _m('g', 'Guru Lakshmi', role: UserRole.guru)};
      const direct = Chat(id: 'x', type: ChatType.direct, memberIds: ['me', 'g'], createdBy: 'me');
      const group = Chat(id: 'y', type: ChatType.group, memberIds: ['me', 'g'], createdBy: 'g', name: 'Batch A');
      expect(direct.titleFor('me', dir), 'Guru Lakshmi');
      expect(group.titleFor('me', dir), 'Batch A');
    });

    test('chat reducer stores chats and messages per chat', () {
      const chat = Chat(id: 'c1', type: ChatType.group, memberIds: ['a'], createdBy: 'a', name: 'G');
      final msg = ChatMessage(id: 'm1', senderId: 'a', senderName: 'A', text: 'hi', createdAt: DateTime(2026));
      var s = appReducer(AppState.initial(), const ChatsLoadedAction([chat]));
      s = appReducer(s, MessagesLoadedAction('c1', [msg]));
      expect(s.chat.groups, [chat]);
      expect(s.chat.direct, isEmpty);
      expect(s.chat.messages['c1'], [msg]);
    });

    test('a send failure is kept until cleared', () {
      var s = appReducer(AppState.initial(), const ChatSendFailedAction('boom'));
      expect(s.chat.sendError, 'boom');
      s = appReducer(s, const ClearChatSendErrorAction());
      expect(s.chat.sendError, isNull);
    });

    test('signing out clears chats and the directory', () {
      var s = appReducer(AppState.initial(), DirectoryLoadedAction([_m('a', 'A')]));
      s = appReducer(s, const SignedOutAction());
      expect(s.directory.items, isEmpty);
      expect(s.chat.chats, isEmpty);
    });
  });

  group('who a student may message', () {
    const student = AppUser(id: 'st', name: 'Ananya', role: UserRole.student, schoolId: 's');
    final guru = _m('g', 'Guru', role: UserRole.guru);
    final classmate = _m('c', 'Classmate');

    test('a student cannot start a chat with another student', () async {
      final store = _store(student, directory: [guru, classmate]);
      final result = await store.dispatch(startDirectChat('c')) as ChatOpenResult;
      expect(result.chatId, isNull);
      expect(result.error, contains('guru'));
    });

    test('a student cannot create a group', () async {
      final store = _store(student, directory: [guru]);
      final result = await store.dispatch(createGroupChat('Mine', ['g'])) as ChatOpenResult;
      expect(result.chatId, isNull);
      expect(result.error, contains('Only'));
    });

    test('starting a chat while offline reports it', () async {
      final store = _store(student, directory: [guru]);
      store.dispatch(const SetConnectivityAction(isOnline: false));
      final result = await store.dispatch(startDirectChat('g')) as ChatOpenResult;
      expect(result.error, contains('offline'));
    });
  });
}
