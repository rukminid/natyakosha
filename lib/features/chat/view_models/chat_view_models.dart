import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/chat.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/member.dart';
import '../../../redux/actions/app_actions.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/chat_thunks.dart' as ct;

/// One row of the chat list, with its title and avatar already resolved.
class ChatListItem extends Equatable {
  const ChatListItem({required this.chat, required this.title, required this.other, required this.preview});

  final Chat chat;
  final String title;

  /// The other person in a direct chat (for the photo); null for groups.
  final Member? other;
  final String preview;

  @override
  List<Object?> get props => [chat, title, other, preview];
}

/// Chat tab: Individual and Groups.
class ChatListViewModel extends Equatable {
  const ChatListViewModel({
    required this.direct,
    required this.groups,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.start,
  });

  final List<ChatListItem> direct;
  final List<ChatListItem> groups;
  final bool loading;
  final String? error;
  final bool isStaff;
  final Future<void> Function() start;

  static ChatListViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    final me = s.auth.user!;
    final directory = {for (final m in s.directory.items) m.id: m};

    ChatListItem item(Chat c) {
      final other = c.isGroup ? null : directory[c.otherMemberId(me.id)];
      final last = c.lastMessage;
      final preview = last == null
          ? (c.isGroup ? 'No messages yet' : '')
          : (c.lastSenderId == me.id ? 'You: $last' : last);
      return ChatListItem(chat: c, title: c.titleFor(me.id, directory), other: other, preview: preview);
    }

    return ChatListViewModel(
      // A one-to-one chat with no message yet is just an opened picker.
      direct: [for (final c in s.chat.direct) if (c.lastMessage != null) item(c)],
      groups: [for (final c in s.chat.groups) item(c)],
      loading: s.chat.loading,
      error: s.chat.error,
      isStaff: me.role.isStaff,
      start: () async {
        store.dispatch(ct.startChatListener());
        store.dispatch(ct.loadDirectory());
      },
    );
  }

  @override
  List<Object?> get props => [direct, groups, loading, error, isStaff];
}

/// The people list for starting a chat or building a group.
class PeopleViewModel extends Equatable {
  const PeopleViewModel({
    required this.people,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.isOnline,
    required this.myId,
    required this.load,
    required this.startDirect,
    required this.createGroup,
  });

  /// Everyone I may chat with, by name (never myself).
  final List<Member> people;
  final bool loading;
  final String? error;
  final bool isStaff;
  final bool isOnline;
  final String myId;
  final Future<void> Function() load;

  /// Returns the chat id, or an error message.
  final Future<ct.ChatOpenResult> Function(String otherId) startDirect;
  final Future<ct.ChatOpenResult> Function(String name, List<String> memberIds) createGroup;

  static PeopleViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    final me = s.auth.user!;
    return PeopleViewModel(
      // Students and parents can only message staff. Students the guru added
      // have no login, so they are not offered either.
      people: [
        for (final m in s.directory.items)
          if (m.id != me.id && !m.managed && (me.role.isStaff || m.isStaff)) m,
      ],
      loading: s.directory.loading,
      error: s.directory.error,
      isStaff: me.role.isStaff,
      isOnline: s.isOnline,
      myId: me.id,
      load: () async => store.dispatch(ct.loadDirectory()),
      startDirect: (otherId) async =>
          await store.dispatch(ct.startDirectChat(otherId)) as ct.ChatOpenResult,
      createGroup: (name, ids) async =>
          await store.dispatch(ct.createGroupChat(name, ids)) as ct.ChatOpenResult,
    );
  }

  @override
  List<Object?> get props => [people, loading, error, isStaff, isOnline, myId];
}

/// One conversation.
class ChatRoomViewModel extends Equatable {
  const ChatRoomViewModel({
    required this.chat,
    required this.title,
    required this.messages,
    required this.myId,
    required this.members,
    required this.sendError,
    required this.open,
    required this.close,
    required this.send,
    required this.clearSendError,
  });

  /// Null while the chat list is still loading.
  final Chat? chat;
  final String title;

  /// Newest first.
  final List<ChatMessage> messages;
  final String myId;
  final List<Member> members;
  final String? sendError;
  final void Function() open;
  final void Function() close;
  final void Function(String text) send;
  final void Function() clearSendError;

  bool get isGroup => chat?.isGroup ?? false;

  static ChatRoomViewModel fromStore(Store<AppState> store, String chatId) {
    final s = store.state;
    final me = s.auth.user!;
    final c = s.chat.chatById(chatId);
    final directory = {for (final m in s.directory.items) m.id: m};
    return ChatRoomViewModel(
      chat: c,
      title: c?.titleFor(me.id, directory) ?? 'Chat',
      messages: s.chat.messages[chatId] ?? const [],
      myId: me.id,
      members: [
        for (final id in c?.memberIds ?? const <String>[])
          directory[id] ?? Member(id: id, name: 'Member', role: me.role),
      ],
      sendError: s.chat.sendError,
      open: () {
        store.dispatch(ct.startChatListener());
        store.dispatch(ct.loadDirectory());
        store.dispatch(ct.openChat(chatId));
      },
      close: () => store.dispatch(ct.closeChat(chatId)),
      send: (text) => store.dispatch(ct.sendChatMessage(chatId, text)),
      clearSendError: () => store.dispatch(const ClearChatSendErrorAction()),
    );
  }

  @override
  List<Object?> get props => [chat, title, messages, myId, members, sendError];
}
