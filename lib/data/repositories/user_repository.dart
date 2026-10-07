import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/member.dart';
import '../models/model_utils.dart';
import '../services/firestore_paths.dart';

/// Members of a school: student lists and join-request approvals.
class UserRepository {
  UserRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<AppUser>> fetchStudents(String schoolId, {String? batchId}) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection(FirestorePaths.users)
          .where('schoolId', isEqualTo: schoolId)
          .where('role', isEqualTo: UserRole.student.name)
          .where('status', isEqualTo: AccountStatus.approved.name);
      if (batchId != null) q = q.where('batchId', isEqualTo: batchId);
      final snap = await q.get();
      return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// People who signed up for this institute and are waiting for approval.
  Future<List<AppUser>> fetchPending(String schoolId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.users)
          .where('schoolId', isEqualTo: schoolId)
          .where('status', isEqualTo: AccountStatus.pending.name)
          .get();
      return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> review({
    required String uid,
    required bool approve,
    required String reviewerId,
  }) async {
    try {
      await _db.doc(FirestorePaths.user(uid)).update({
        'status': (approve ? AccountStatus.approved : AccountStatus.rejected).name,
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A user edits their own profile. Role, school and approval status are
  /// not touched here (the security rules block them too).
  Future<void> updateProfile({
    required String uid,
    required String name,
    required DateTime? dob,
    required Gender? gender,
    String? photoUrl,
  }) async {
    try {
      await _db.doc(FirestorePaths.user(uid)).update({
        'name': name.trim(),
        'dob': writeTimestamp(dob),
        'gender': gender?.name,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// The guru adds a student who has no login (they may never use the app).
  /// The record is a normal approved student, so attendance, events and fees
  /// pick it up; `managed` marks that only staff maintain it. The directory
  /// entry lets the birthday board show them. Returns the new student's id.
  Future<String> addManagedStudent({
    required AppUser staff,
    required String name,
    DateTime? dob,
    Gender? gender,
    String? guardianPhone,
  }) async {
    try {
      final ref = _db.collection(FirestorePaths.users).doc();
      final student = AppUser(
        id: ref.id,
        name: name.trim(),
        role: UserRole.student,
        schoolId: staff.schoolId,
        schoolName: staff.schoolName,
        status: AccountStatus.approved,
        dob: dob,
        gender: gender,
        guardianPhone: guardianPhone,
        managed: true,
      );
      final batch = _db.batch();
      batch.set(ref, {
        ...student.toMap(),
        'createdBy': staff.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(_directoryDoc(staff.schoolId, ref.id), _directoryEntry(student));
      await batch.commit();
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Edits a guru-added student ([student] carries the new values).
  Future<void> updateManagedStudent({required AppUser student}) async {
    try {
      final batch = _db.batch();
      batch.update(_db.doc(FirestorePaths.user(student.id)), {
        'name': student.name.trim(),
        'dob': writeTimestamp(student.dob),
        'gender': student.gender?.name,
        'guardianPhone': student.guardianPhone,
      });
      batch.set(_directoryDoc(student.schoolId, student.id), _directoryEntry(student));
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Takes a guru-added student off the roster. The record stays (past
  /// attendance still refers to it), marked `inactive`.
  Future<void> removeManagedStudent({required AppUser student}) async {
    try {
      final batch = _db.batch();
      batch.update(_db.doc(FirestorePaths.user(student.id)), {'status': AccountStatus.inactive.name});
      batch.delete(_directoryDoc(student.schoolId, student.id));
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  DocumentReference<Map<String, dynamic>> _directoryDoc(String schoolId, String uid) =>
      _db.collection(FirestorePaths.directory(schoolId)).doc(uid);

  Map<String, dynamic> _directoryEntry(AppUser student) => {
        ...Member.fromUser(student).toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
