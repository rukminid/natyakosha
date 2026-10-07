import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';

/// Uploads files to Cloud Storage. Images are compressed on the phone first
/// (a 4 MB photo becomes ~300 KB), which keeps storage inside the free tier.
class StorageService {
  StorageService([FirebaseStorage? storage]) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Compresses the image at [localPath] and uploads it to [storagePath].
  /// Returns the public download URL.
  Future<String> uploadImage({
    required String localPath,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await compressImage(localPath);
    return uploadBytes(
      bytes: bytes,
      storagePath: storagePath,
      contentType: 'image/jpeg',
      onProgress: onProgress,
    );
  }

  Future<Uint8List> compressImage(String localPath) async {
    final result = await FlutterImageCompress.compressWithFile(
      localPath,
      minWidth: Env.imageMaxDimension,
      minHeight: Env.imageMaxDimension,
      quality: Env.imageQuality,
      format: CompressFormat.jpeg,
    );
    if (result == null) {
      throw const AppException('Could not read that image. Please pick another one.');
    }
    return result;
  }

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref(storagePath);
      final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
      if (onProgress != null) {
        task.snapshotEvents.listen(
          (s) {
            if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
          },
          // Failures are handled by `await task` below.
          onError: (Object _) {},
        );
      }
      await task;
      return await ref.getDownloadURL();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Streams a large file (video, audio) from disk without loading it into
  /// memory. Returns the download URL.
  Future<String> uploadFile({
    required String localPath,
    required String storagePath,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref(storagePath);
      final task = ref.putFile(File(localPath), SettableMetadata(contentType: contentType));
      if (onProgress != null) {
        task.snapshotEvents.listen(
          (s) {
            if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
          },
          onError: (Object _) {},
        );
      }
      await task;
      return await ref.getDownloadURL();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteByUrl(String url) => _storage.refFromURL(url).delete();
}
