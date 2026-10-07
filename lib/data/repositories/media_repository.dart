import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../models/media_item.dart';
import '../services/firestore_paths.dart';
import '../services/storage_service.dart';

/// Gallery: photos, videos and audio clips of events, with the files in
/// Cloud Storage and one `media` document per file.
class MediaRepository {
  MediaRepository(this._storage, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final StorageService _storage;
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(FirestorePaths.media(schoolId));

  /// The school's latest media, newest first.
  Future<List<MediaItem>> fetchMedia(String schoolId) async {
    try {
      final snap = await _col(schoolId).orderBy('createdAt', descending: true).limit(300).get();
      return snap.docs.map((d) => MediaItem.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Uploads one file and records it. Photos are compressed first.
  Future<void> upload({
    required String schoolId,
    required String uploadedBy,
    required String eventId,
    required MediaType type,
    required String localPath,
    String? itemId,
    String? caption,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final id = _uuid.v4();
      final String url;
      switch (type) {
        case MediaType.photo:
          url = await _storage.uploadImage(
            localPath: localPath,
            storagePath: StoragePaths.eventPhoto(schoolId, eventId, '$id.jpg'),
            onProgress: onProgress,
          );
        case MediaType.video:
          url = await _storage.uploadFile(
            localPath: localPath,
            storagePath: StoragePaths.eventVideo(schoolId, eventId, '$id${_ext(localPath, 'mp4')}'),
            contentType: contentTypeFor(type, localPath),
            onProgress: onProgress,
          );
        case MediaType.audio:
          url = await _storage.uploadFile(
            localPath: localPath,
            storagePath: StoragePaths.eventAudio(schoolId, eventId, '$id${_ext(localPath, 'm4a')}'),
            contentType: contentTypeFor(type, localPath),
            onProgress: onProgress,
          );
      }
      final item = MediaItem(
        id: id,
        eventId: eventId,
        itemId: itemId,
        type: type,
        url: url,
        caption: (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
        uploadedBy: uploadedBy,
      );
      await _col(schoolId).doc(id).set({
        ...item.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes the document, then the file (a leftover file is harmless; a
  /// leftover document pointing at nothing is not).
  Future<void> delete(String schoolId, MediaItem item) async {
    try {
      await _col(schoolId).doc(item.id).delete();
      try {
        await _storage.deleteByUrl(item.url);
      } catch (_) {
        // File already gone or not deletable: the gallery entry is removed either way.
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// `.mp4` style extension of [path] (with the dot), or `.fallback`.
  static String _ext(String path, String fallback) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext) ? '.$ext' : '.$fallback';
  }

  /// MIME type from the file extension; Storage rules only check size.
  static String contentTypeFor(MediaType type, String path) {
    final ext = _ext(path, '').replaceFirst('.', '');
    switch (type) {
      case MediaType.photo:
        return 'image/jpeg';
      case MediaType.video:
        return switch (ext) {
          'mov' => 'video/quicktime',
          '3gp' => 'video/3gpp',
          'webm' => 'video/webm',
          'mkv' => 'video/x-matroska',
          _ => 'video/mp4',
        };
      case MediaType.audio:
        return switch (ext) {
          'mp3' => 'audio/mpeg',
          'wav' => 'audio/wav',
          'aac' => 'audio/aac',
          'ogg' => 'audio/ogg',
          'flac' => 'audio/flac',
          _ => 'audio/mp4',
        };
    }
  }
}
