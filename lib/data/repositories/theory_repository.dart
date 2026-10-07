import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/storage_keys.dart';
import '../models/theory_note.dart';
import '../services/firestore_paths.dart';
import '../services/storage_service.dart';

/// Theory notes: text plus a few images, read by the whole school and
/// written by staff. Notes are cached so they can be read offline.
class TheoryRepository {
  TheoryRepository(this._storage, this._store, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final StorageService _storage;
  final LocalStore _store;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(FirestorePaths.theory(schoolId));

  List<TheoryNote> cached() =>
      _store.getList(StorageKeys.cachedTheory).map(TheoryNote.fromJson).toList();

  /// Every note, by topic then title. Falls back to the cache when offline.
  Future<List<TheoryNote>> fetchAll(String schoolId) async {
    try {
      final snap = await _col(schoolId).get();
      final list = sortNotes(snap.docs.map((d) => TheoryNote.fromMap(d.id, d.data())).toList());
      await _store.putJson(StorageKeys.cachedTheory, list.map((n) => n.toJson()).toList());
      return list;
    } catch (e) {
      final fallback = cached();
      if (fallback.isNotEmpty) return fallback;
      throw AppException.from(e);
    }
  }

  /// Creates the note (empty [note].id) or edits it. New images are
  /// compressed and uploaded; [removedUrls] are dropped from the note and
  /// deleted from Storage once the note is saved. Returns the note id.
  Future<String> save({
    required String schoolId,
    required TheoryNote note,
    List<String> newImagePaths = const [],
    List<String> removedUrls = const [],
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = note.id.isEmpty ? _col(schoolId).doc() : _col(schoolId).doc(note.id);
      final urls = [...note.imageUrls.where((u) => !removedUrls.contains(u))];
      for (var i = 0; i < newImagePaths.length; i++) {
        urls.add(await _storage.uploadImage(
          localPath: newImagePaths[i],
          storagePath: StoragePaths.theoryImage(
            schoolId,
            ref.id,
            '${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ),
          onProgress: (p) => onProgress?.call((i + p) / newImagePaths.length),
        ));
      }
      await ref.set({
        'topic': note.topic,
        'title': note.title,
        'body': note.body,
        'level': note.level,
        'imageUrls': urls,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _deleteImages(removedUrls);
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete(String schoolId, TheoryNote note) async {
    try {
      await _col(schoolId).doc(note.id).delete();
      await _deleteImages(note.imageUrls);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A leftover file is harmless, so failures here are ignored.
  Future<void> _deleteImages(List<String> urls) async {
    for (final u in urls) {
      try {
        await _storage.deleteByUrl(u);
      } catch (_) {}
    }
  }

  /// By topic, then title, ignoring case.
  static List<TheoryNote> sortNotes(List<TheoryNote> notes) => [...notes]
    ..sort((a, b) {
      final t = a.topic.toLowerCase().compareTo(b.topic.toLowerCase());
      return t != 0 ? t : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
}
