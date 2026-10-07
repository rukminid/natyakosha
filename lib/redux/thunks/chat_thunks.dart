import 'dart:async';

import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/chat.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/directory_repository.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';

ChatRepository get _repo => locator<ChatRepository>();

StreamSubscription<List<Chat>>? _chatsSub;
final _messageSubs = <String, StreamSubscription<List<ChatMessage>>>{};

/// Everyone in the school, for the chat picker and the birthday board.
AppThunk loadDirectory() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.isApproved || !store.state.firebaseReady) return;
      store.dispatch(const DirectoryRequestAction());
      try {
        store.dispatch(DirectoryLoadedAction(
          await locator<DirectoryRepository>().fetchMembers(user.schoolId),
        ));
      } catch (e) {
        store.dispatch(DirectoryFailureAction(AppException.from(e).message));
      }
    };

/// Starts the live list of my chats. Safe to call again; it only subscribes once.
AppThunk startChatListener() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.isApproved || !store.state.firebaseReady) return;
      if (_chatsSub != null) return;
      store.dispatch(const ChatsRequestAction());
      _chatsSub = _repo.watchChats(user.schoolId, user.id).listen(
            (items) => store.dispatch(ChatsLoadedAction(items)),
            onError: (Object e) => store.dispatch(ChatsFailureAction(AppException.from(e).message)),
          );
    };

/// Cancels every live listener. Call before signing out.
AppThunk stopChatListeners() => (Store<AppState> store) async {
      await _chatsSub?.cancel();
      _chatsSub = null;
      for (final sub in _messageSubs.values) {
        await sub.cancel();
      }
      _messageSubs.clear();
    };

/// Live messages of one chat while its screen is open.
AppThunk openChat(String chatId) => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || _messageSubs.containsKey(chatId)) return;
      _messageSubs[chatId] = _repo.watchMessages(user.schoolId, chatId).listen(
            (items) => store.dispatch(MessagesLoadedAction(chatId, items)),
            onError: (Object e) => store.dispatch(ChatSendFailedAction(AppException.from(e).message)),
          );
    };

AppThunk closeChat(String chatId) => (Store<AppState> store) async {
      await _messageSubs.remove(chatId)?.cancel();
    };

/// Sends without waiting for the server, so it works from a hall with no
/// signal: Firestore queues the write and delivers it later.
AppThunk sendChatMessage(String chatId, String text) => (Store<AppState> store) async {
      final me = store.state.auth.user;
      final body = text.trim();
      if (me == null || body.isEmpty) return;
      unawaited(_repo
          .sendMessage(
            schoolId: me.schoolId,
            chatId: chatId,
            senderId: me.id,
            senderName: me.name,
            text: body.length > 2000 ? body.substring(0, 2000) : body,
          )
          .catchError((Object e) => store.dispatch(ChatSendFailedAction(AppException.from(e).message))));
    };

typedef ChatOpenResult = ({String? chatId, String? error});

/// Finds or creates my one-to-one chat with [otherId].
/// Students and parents can only message staff, like the security rules.
Future<ChatOpenResult> Function(Store<AppState>) startDirectChat(String otherId) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null) return (chatId: null, error: 'Please sign in again.');
      if (!store.state.isOnline) return (chatId: null, error: AppException.offline.message);
      final other = store.state.directory.items.where((m) => m.id == otherId).firstOrNull;
      if (!me.role.isStaff && !(other?.isStaff ?? false)) {
        return (chatId: null, error: 'You can message your guru and teachers.');
      }
      try {
        final id = await _repo.ensureDirectChat(schoolId: me.schoolId, myId: me.id, otherId: otherId);
        return (chatId: id, error: null);
      } catch (e) {
        return (chatId: null, error: AppException.from(e).message);
      }
    };

/// Staff only.
Future<ChatOpenResult> Function(Store<AppState>) createGroupChat(String name, List<String> memberIds) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) {
        return (chatId: null, error: 'Only your guru or teachers can create groups.');
      }
      if (!store.state.isOnline) return (chatId: null, error: AppException.offline.message);
      try {
        final id = await _repo.createGroup(
          schoolId: me.schoolId,
          createdBy: me.id,
          name: name,
          memberIds: memberIds,
        );
        return (chatId: id, error: null);
      } catch (e) {
        return (chatId: null, error: AppException.from(e).message);
      }
    };

/// Writes my own directory entry (name, photo, birthday day+month) so other
/// members can find me and see my birthday. Fire-and-forget.
void syncDirectoryEntry(Store<AppState> store, AppUser user) {
  if (!user.isApproved || !store.state.firebaseReady || !store.state.isOnline) return;
  unawaited(locator<DirectoryRepository>().upsertSelf(user).catchError((Object _) {}));
}
