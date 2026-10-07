import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/attendance_record.dart';
import '../models/attendance_summary.dart';
import '../models/model_utils.dart';
import '../services/firestore_paths.dart';

/// Attendance works offline: Firestore queues the write locally and syncs
/// when the phone is back online, so there is no custom sync queue here.
class AttendanceRepository {
  AttendanceRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<AttendanceRecord?> fetch(String schoolId, DateTime date,
      [String batchId = AttendanceRecord.allStudents]) async {
    try {
      final id = AttendanceRecord.docId(date, batchId);
      final snap = await _db.collection(FirestorePaths.attendance(schoolId)).doc(id).get();
      final data = snap.data();
      return data == null ? null : AttendanceRecord.fromMap(id, data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// All class days in one month, oldest first.
  Future<List<AttendanceRecord>> fetchMonth(String schoolId, int year, int month) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.attendance(schoolId))
          .where('date', isGreaterThanOrEqualTo: writeTimestamp(DateTime(year, month)))
          .where('date', isLessThan: writeTimestamp(DateTime(year, month + 1)))
          .orderBy('date')
          .get();
      return snap.docs.map((d) => AttendanceRecord.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Don't await this when offline — the future only completes after the
  /// server confirms. The local write is visible to reads immediately.
  ///
  /// Each student's mark is also written to their own `studentAttendance`
  /// folder in the same batch, so a student or parent can read just their
  /// own days without access to the whole class sheet.
  Future<void> save(String schoolId, AttendanceRecord record) async {
    try {
      final batch = _db.batch();
      batch.set(_db.collection(FirestorePaths.attendance(schoolId)).doc(record.id), {
        ...record.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final e in record.marks.entries) {
        batch.set(_db.collection(FirestorePaths.studentDays(schoolId, e.key)).doc(record.id), {
          'date': writeTimestamp(record.date),
          'present': e.value,
          'batchId': record.batchId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// One student's class days in a month, oldest first.
  Future<List<StudentDay>> fetchStudentMonth(String schoolId, String studentId, int year, int month) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.studentDays(schoolId, studentId))
          .where('date', isGreaterThanOrEqualTo: writeTimestamp(DateTime(year, month)))
          .where('date', isLessThan: writeTimestamp(DateTime(year, month + 1)))
          .orderBy('date')
          .get();
      return [
        for (final d in snap.docs)
          StudentDay(
            date: AttendanceRecord.dayOf(readDate(d.data()['date']) ?? DateTime.now()),
            present: d.data()['present'] == true,
            batchId: d.data()['batchId'] as String? ?? AttendanceRecord.allStudents,
          ),
      ];
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
