import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// `schools/{schoolId}/chats/{chatId}/messages/{messageId}`
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  /// A message still waiting for the server timestamp has no `createdAt`
  /// yet; it is shown as "now" so it appears at the bottom straight away.
  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) => ChatMessage(
        id: id,
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt: readDate(map['createdAt']) ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [id, senderId, senderName, text, createdAt];
}
