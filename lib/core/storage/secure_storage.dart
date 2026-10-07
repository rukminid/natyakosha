import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// react-native-keychain equivalent: encrypted storage for tokens/secrets.
/// (Firebase Auth already persists its own session securely; use this for
/// anything extra, such as the FCM token or third-party API keys.)
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
  Future<void> clear() => _storage.deleteAll();
}
