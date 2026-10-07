/// Every Firestore path in one place. Mirrors firestore.rules.
///
/// users/{uid}                                   profile + role + schoolId
/// schools/{schoolId}
///   batches/{batchId}
///   attendance/{yyyy-MM-dd_batchId}
///   studentAttendance/{studentId}/days/{yyyy-MM-dd_batchId}   one student's own marks
///   payments/{paymentId}
///   events/{eventId}
///     items/{itemId}                            running order (songs)
///     fees/{studentId}                          per-participant event fee
///   media/{mediaId}
///   groups/{groupId}
///   announcements/{id}
///   directory/{uid}                              name, role, photo, birthday (day+month)
///   chats/{chatId}                              direct or group conversation
///     messages/{messageId}
///   theory/{noteId}
class FirestorePaths {
  FirestorePaths._();

  static String user(String uid) => 'users/$uid';
  static const users = 'users';

  static const schools = 'schools';
  static String school(String s) => 'schools/$s';
  static String batches(String s) => 'schools/$s/batches';
  static String attendance(String s) => 'schools/$s/attendance';
  static String studentDays(String s, String studentId) => 'schools/$s/studentAttendance/$studentId/days';
  static String payments(String s) => 'schools/$s/payments';
  static String events(String s) => 'schools/$s/events';
  static String eventItems(String s, String e) => 'schools/$s/events/$e/items';
  static String eventFees(String s, String e) => 'schools/$s/events/$e/fees';
  static String media(String s) => 'schools/$s/media';
  static String groups(String s) => 'schools/$s/groups';
  static String announcements(String s) => 'schools/$s/announcements';
  static String theory(String s) => 'schools/$s/theory';
  static String directory(String s) => 'schools/$s/directory';
  static String chats(String s) => 'schools/$s/chats';
  static String messages(String s, String chatId) => 'schools/$s/chats/$chatId/messages';
}

/// Matching Cloud Storage folders (see storage.rules).
class StoragePaths {
  StoragePaths._();

  static String paymentScreenshot(String s, String studentId, String fileName) =>
      'schools/$s/payments/$studentId/$fileName';
  static String eventFeeScreenshot(String s, String eventId, String studentId, String fileName) =>
      'schools/$s/events/$eventId/fees/$studentId/$fileName';
  static String eventPhoto(String s, String eventId, String fileName) =>
      'schools/$s/events/$eventId/photos/$fileName';
  static String eventVideo(String s, String eventId, String fileName) =>
      'schools/$s/events/$eventId/videos/$fileName';
  static String eventAudio(String s, String eventId, String fileName) =>
      'schools/$s/events/$eventId/audio/$fileName';
  static String profilePhoto(String uid, String fileName) => 'users/$uid/profile/$fileName';
  static String theoryImage(String s, String noteId, String fileName) =>
      'schools/$s/theory/$noteId/$fileName';
}
