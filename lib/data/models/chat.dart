import 'package:equatable/equatable.dart';

import 'member.dart';
import 'model_utils.dart';

enum ChatType { direct, group }

/// `schools/{schoolId}/chats/{chatId}`: a one-to-one or group conversation.
/// Messages live in its `messages` sub-collection.
class Chat extends Equatable {
  const Chat({
    required this.id,
    required this.type,
    required this.memberIds,
    required this.createdBy,
    this.name,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.createdAt,
  });

  final String id;
  final ChatType type;
  final List<String> memberIds;
  final String createdBy;

  /// Groups only.
  final String? name;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final DateTime? createdAt;

  bool get isGroup => type == ChatType.group;

  /// Same id for the same two people no matter who starts the chat,
  /// so a pair never ends up with two conversations.
  static String directId(String a, String b) => a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';

  String? otherMemberId(String myId) {
    for (final id in memberIds) {
      if (id != myId) return id;
    }
    return null;
  }

  /// The group name, or the other person's name for a direct chat.
  String titleFor(String myId, Map<String, Member> directory) {
    if (isGroup) return (name == null || name!.isEmpty) ? 'Group' : name!;
    final other = otherMemberId(myId);
    return directory[other]?.name ?? 'Chat';
  }

  /// Last activity, falling back to creation, for sorting the list.
  DateTime get sortTime => lastMessageAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory Chat.fromMap(String id, Map<String, dynamic> map) => Chat(
        id: id,
        type: readEnum(ChatType.values, map['type'], ChatType.direct),
        memberIds: readStringList(map['memberIds']),
        createdBy: map['createdBy'] as String? ?? '',
        name: map['name'] as String?,
        lastMessage: map['lastMessage'] as String?,
        lastMessageAt: readDate(map['lastMessageAt']),
        lastSenderId: map['lastSenderId'] as String?,
        createdAt: readDate(map['createdAt']),
      );

  @override
  List<Object?> get props =>
      [id, type, memberIds, createdBy, name, lastMessage, lastMessageAt, lastSenderId, createdAt];
}
