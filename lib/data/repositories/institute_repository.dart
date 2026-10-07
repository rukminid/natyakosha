import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/institute.dart';
import '../services/firestore_paths.dart';

/// Institutes for the sign-up dropdown (readable before sign-in).
class InstituteRepository {
  InstituteRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<Institute>> fetchActive() async {
    try {
      final snap = await _db.collection(FirestorePaths.schools).where('active', isEqualTo: true).get();
      final list = snap.docs.map((d) => Institute.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
