import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/batch.dart';
import '../services/firestore_paths.dart';

/// Class batches ("Beginners – Sat 5pm") and which students are in each.
/// A student is in at most one batch: their `batchId`.
class BatchRepository {
  BatchRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(FirestorePaths.batches(schoolId));

  Future<List<Batch>> fetchAll(String schoolId) async {
    try {
      final snap = await _col(schoolId).get();
      return snap.docs.map((d) => Batch.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Creates the batch (empty [batch].id) or edits it. Returns its id.
  Future<String> save(String schoolId, Batch batch) async {
    try {
      final ref = batch.id.isEmpty ? _col(schoolId).doc() : _col(schoolId).doc(batch.id);
      await ref.set(batch.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes the batch and takes everyone out of it. Past attendance for
  /// the batch is kept.
  Future<void> delete(String schoolId, String batchId) async {
    try {
      final members = await _db
          .collection(FirestorePaths.users)
          .where('schoolId', isEqualTo: schoolId)
          .where('batchId', isEqualTo: batchId)
          .get();
      final batch = _db.batch()..delete(_col(schoolId).doc(batchId));
      for (final m in members.docs) {
        batch.update(m.reference, {'batchId': null});
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Makes [memberIds] the students of [batchId]. [previousIds] (who was in
  /// it before) are taken out when not in the new list.
  Future<void> setMembers(
    String batchId, {
    required Set<String> memberIds,
    required Set<String> previousIds,
  }) async {
    try {
      final plan = membershipChanges(batchId, memberIds: memberIds, previousIds: previousIds);
      if (plan.isEmpty) return;
      final batch = _db.batch();
      plan.forEach((uid, value) => batch.update(_db.doc(FirestorePaths.user(uid)), {'batchId': value}));
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// uid → new `batchId` (null = out of the batch), for only the people who change.
  static Map<String, String?> membershipChanges(
    String batchId, {
    required Set<String> memberIds,
    required Set<String> previousIds,
  }) =>
      {
        for (final id in memberIds.difference(previousIds)) id: batchId,
        for (final id in previousIds.difference(memberIds)) id: null,
      };
}
