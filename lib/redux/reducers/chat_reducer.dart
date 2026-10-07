import 'package:redux/redux.dart';

import '../actions/app_actions.dart';
import '../state/chat_state.dart';

final chatReducer = combineReducers<ChatState>([
  TypedReducer<ChatState, ChatsRequestAction>((s, _) => s.copyWith(loading: true)).call,
  TypedReducer<ChatState, ChatsLoadedAction>(
    (s, a) => s.copyWith(chats: a.items, loading: false, error: () => null),
  ).call,
  TypedReducer<ChatState, ChatsFailureAction>(
    (s, a) => s.copyWith(loading: false, error: () => a.message),
  ).call,
  TypedReducer<ChatState, MessagesLoadedAction>(
    (s, a) => s.copyWith(messages: {...s.messages, a.chatId: a.items}),
  ).call,
  TypedReducer<ChatState, ChatSendFailedAction>(
    (s, a) => s.copyWith(sendError: () => a.message),
  ).call,
  TypedReducer<ChatState, ClearChatSendErrorAction>(
    (s, _) => s.copyWith(sendError: () => null),
  ).call,
]);
