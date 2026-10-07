import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/payment.dart';
import '../services/firestore_paths.dart';
import '../services/storage_service.dart';

/// Monthly fee payments: "pay by UPI, upload the screenshot, guru verifies".
class PaymentRepository {
  PaymentRepository(this._storage, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final StorageService _storage;
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> _col(String schoolId) =>
      _db.collection(FirestorePaths.payments(schoolId));

  /// Staff see the school's latest payments; students/parents see their own.
  Future<List<Payment>> fetchFor(AppUser user) async {
    try {
      final Query<Map<String, dynamic>> q;
      if (user.role.isStaff) {
        q = _col(user.schoolId).orderBy('submittedAt', descending: true).limit(200);
      } else {
        final ids = user.role == UserRole.parent ? user.childIds : [user.id];
        if (ids.isEmpty) return const [];
        // whereIn allows up to 30 values — plenty for one family.
        q = _col(user.schoolId).where('studentId', whereIn: ids.take(30).toList());
      }
      final snap = await q.get();
      final list = snap.docs.map((d) => Payment.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));
      return list;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Compresses + uploads the screenshot, then records the payment as
  /// `submitted` so it shows in the guru's "to verify" list.
  Future<Payment> submit({
    required AppUser student,
    required String month,
    required double amount,
    required String screenshotPath,
    String? upiTxnId,
    String? note,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final id = _uuid.v4();
      final url = await _storage.uploadImage(
        localPath: screenshotPath,
        storagePath: StoragePaths.paymentScreenshot(student.schoolId, student.id, '$month-$id.jpg'),
        onProgress: onProgress,
      );
      final payment = Payment(
        id: id,
        studentId: student.id,
        studentName: student.name,
        month: month,
        amount: amount,
        status: PaymentStatus.submitted,
        upiTxnId: (upiTxnId?.isEmpty ?? true) ? null : upiTxnId,
        screenshotUrl: url,
        note: (note?.isEmpty ?? true) ? null : note,
        submittedAt: DateTime.now(),
      );
      await _col(student.schoolId).doc(id).set(payment.toMap());
      return payment;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Guru marks a payment verified or rejected.
  Future<void> review({
    required String schoolId,
    required String paymentId,
    required bool approve,
    required String reviewerId,
    String? note,
  }) async {
    try {
      await _col(schoolId).doc(paymentId).update({
        'status': (approve ? PaymentStatus.verified : PaymentStatus.rejected).name,
        'verifiedBy': reviewerId,
        'verifiedAt': FieldValue.serverTimestamp(),
        if (note != null) 'note': note,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
