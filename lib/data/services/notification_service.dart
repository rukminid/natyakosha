import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/storage/secure_storage.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import 'firestore_paths.dart';

/// Push notifications (announcements, fee reminders, "payment verified").
///
/// The app saves each device's FCM token on the user's profile; Cloud
/// Functions read those tokens to send reminders (see README → Cloud Functions).
class NotificationService {
  NotificationService(this._secure, {FirebaseMessaging? messaging, FirebaseFirestore? db})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = db ?? FirebaseFirestore.instance;

  final SecureStorage _secure;
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  Future<void> registerDevice(String uid) async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      // Remember uid|token so a second account on the same phone still registers.
      final key = '$uid|$token';
      if (await _secure.read(StorageKeys.fcmToken) == key) return;

      await _db.doc(FirestorePaths.user(uid)).set(
        {'fcmTokens': FieldValue.arrayUnion([token])},
        SetOptions(merge: true),
      );
      await _secure.write(StorageKeys.fcmToken, key);
    } catch (e, st) {
      // Notifications are nice-to-have; never block sign-in on them.
      AppLogger.w('FCM registration failed', e);
      AppLogger.e('FCM stack', e, st);
    }
  }

  /// Stop this device receiving the signed-out user's notifications.
  Future<void> unregisterDevice(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.doc(FirestorePaths.user(uid)).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      AppLogger.w('FCM unregister failed', e);
    } finally {
      await _secure.delete(StorageKeys.fcmToken);
    }
  }

  /// Foreground messages. Hook this to a SnackBar or local notification.
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
}
