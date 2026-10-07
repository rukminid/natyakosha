import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/storage_keys.dart';
import '../models/announcement.dart';
import '../services/firestore_paths.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._store, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final LocalStore _store;
  final FirebaseFirestore _db;

  List<Announcement> cached() =>
      _store.getList(StorageKeys.cachedAnnouncements).map(Announcement.fromJson).toList();

  /// Latest announcements, pinned first. Falls back to the cache offline.
  Future<List<Announcement>> fetchLatest(String schoolId, {int limit = 20}) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.announcements(schoolId))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final list = snap.docs.map((d) => Announcement.fromMap(d.id, d.data())).toList()
        ..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
      await _store.putJson(
        StorageKeys.cachedAnnouncements,
        list.map((a) => a.toJson()).toList(),
      );
      return list;
    } catch (e) {
      final fallback = cached();
      if (fallback.isNotEmpty) return fallback;
      throw AppException.from(e);
    }
  }

  Future<void> create({
    required String schoolId,
    required String title,
    required String body,
    required String authorName,
    bool pinned = false,
  }) async {
    try {
      await _db.collection(FirestorePaths.announcements(schoolId)).add({
        'title': title,
        'body': body,
        'pinned': pinned,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Edits the text or the pin. The author and the posted time stay as they were.
  Future<void> update({
    required String schoolId,
    required String id,
    required String title,
    required String body,
    required bool pinned,
  }) async {
    try {
      await _db.collection(FirestorePaths.announcements(schoolId)).doc(id).update({
        'title': title,
        'body': body,
        'pinned': pinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete(String schoolId, String id) async {
    try {
      await _db.collection(FirestorePaths.announcements(schoolId)).doc(id).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
