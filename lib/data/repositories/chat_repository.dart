import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/chat.dart';
import '../models/chat_message.dart';
import '../services/firestore_paths.dart';

/// Conversations and their messages. Lists are live streams, so new
/// messages appear without refreshing; Firestore queues sends while offline.
class ChatRepository {
  ChatRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const messageLimit = 200;

  /// Chats [uid] is in. Sorted on the phone, which avoids a composite index.
  Stream<List<Chat>> watchChats(String schoolId, String uid) => _db
      .collection(FirestorePaths.chats(schoolId))
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Chat.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.sortTime.compareTo(a.sortTime)));

  /// Newest first, so the screen can use a reversed list.
  Stream<List<ChatMessage>> watchMessages(String schoolId, String chatId) => _db
      .collection(FirestorePaths.messages(schoolId, chatId))
      .orderBy('createdAt', descending: true)
      .limit(messageLimit)
      .snapshots()
      .map((snap) => snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());

  /// Opens the one-to-one chat with [otherId], creating it the first time.
  Future<String> ensureDirectChat({
    required String schoolId,
    required String myId,
    required String otherId,
  }) async {
    try {
      final id = Chat.directId(myId, otherId);
      final ref = _db.collection(FirestorePaths.chats(schoolId)).doc(id);
      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set({
          'type': ChatType.direct.name,
          'memberIds': [myId, otherId],
          'createdBy': myId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Staff create a group; [memberIds] always includes the creator.
  Future<String> createGroup({
    required String schoolId,
    required String createdBy,
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      final ref = _db.collection(FirestorePaths.chats(schoolId)).doc();
      await ref.set({
        'type': ChatType.group.name,
        'name': name.trim(),
        'memberIds': {createdBy, ...memberIds}.toList(),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Adds the message and refreshes the chat's "last message" in one batch.
  /// The returned future completes when the server confirms; callers that
  /// must stay responsive offline should not await it.
  Future<void> sendMessage({
    required String schoolId,
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      final chatRef = _db.collection(FirestorePaths.chats(schoolId)).doc(chatId);
      final msgRef = _db.collection(FirestorePaths.messages(schoolId, chatId)).doc();
      final batch = _db.batch();
      batch.set(msgRef, {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(chatRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      });
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
