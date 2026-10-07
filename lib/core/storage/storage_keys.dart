/// Every storage key in one place, so nothing collides or gets misspelled.
class StorageKeys {
  StorageKeys._();

  // shared_preferences (AsyncStorage)
  static const onboardingSeen = 'onboarding_seen';
  static const lastSchoolId = 'last_school_id';
  static const themeMode = 'theme_mode';
  static const languageCode = 'language_code';

  // flutter_secure_storage (Keychain / Keystore)
  static const fcmToken = 'fcm_token';

  // Hive boxes (local store)
  static const cacheBox = 'cache';

  // Hive keys inside [cacheBox]
  static const cachedUser = 'user';
  static const cachedAnnouncements = 'announcements';
  static const cachedTheory = 'theory_notes';
}
