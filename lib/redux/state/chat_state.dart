import 'package:equatable/equatable.dart';

import '../../data/models/chat.dart';
import '../../data/models/chat_message.dart';

/// Conversations the user is in, plus the messages of the chats opened so far.
class ChatState extends Equatable {
  const ChatState({
    this.chats = const [],
    this.loading = false,
    this.error,
    this.messages = const {},
    this.sendError,
  });

  const ChatState.initial() : this();

  /// Newest activity first.
  final List<Chat> chats;
  final bool loading;
  final String? error;

  /// chatId → messages, newest first.
  final Map<String, List<ChatMessage>> messages;

  /// A message that could not be sent (kept apart from [error], the list error).
  final String? sendError;

  List<Chat> get direct => chats.where((c) => !c.isGroup).toList();
  List<Chat> get groups => chats.where((c) => c.isGroup).toList();

  Chat? chatById(String id) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Pass `error: () => null` / `sendError: () => null` to clear.
  ChatState copyWith({
    List<Chat>? chats,
    bool? loading,
    String? Function()? error,
    Map<String, List<ChatMessage>>? messages,
    String? Function()? sendError,
  }) =>
      ChatState(
        chats: chats ?? this.chats,
        loading: loading ?? this.loading,
        error: error != null ? error() : this.error,
        messages: messages ?? this.messages,
        sendError: sendError != null ? sendError() : this.sendError,
      );

  @override
  List<Object?> get props => [chats, loading, error, messages, sendError];
}
