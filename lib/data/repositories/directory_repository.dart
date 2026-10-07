import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/member.dart';
import '../services/firestore_paths.dart';

/// The school directory: who is in the school, for chat pickers and the
/// birthday board. Everyone keeps their own entry up to date.
class DirectoryRepository {
  DirectoryRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<Member>> fetchMembers(String schoolId) async {
    try {
      final snap = await _db.collection(FirestorePaths.directory(schoolId)).get();
      return snap.docs.map((d) => Member.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Writes the signed-in user's own entry. Safe to repeat; it is how
  /// existing accounts get an entry the first time they open the app.
  Future<void> upsertSelf(AppUser user) async {
    try {
      await _db.collection(FirestorePaths.directory(user.schoolId)).doc(user.id).set({
        ...Member.fromUser(user).toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
