import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/utils/mobile_number.dart';
import '../models/app_user.dart';
import '../models/signup_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_paths.dart';

/// Sign-up, mobile + password sign-in, password reset, and the user's
/// profile (`users/{uid}`), cached for offline start.
class AuthRepository {
  AuthRepository(this._auth, this._store, this._api, {FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final AuthService _auth;
  final LocalStore _store;
  final ApiService _api;
  final FirebaseFirestore _db;

  bool get hasSession => _auth.currentUser != null;
  String? get currentUid => _auth.currentUser?.uid;

  Future<AppUser> signIn(String mobile, String password) async {
    final tenDigits = _requireMobile(mobile);
    try {
      final user = await _auth.signIn(
        email: MobileNumber.authEmail(tenDigits),
        password: password,
      );
      return await fetchProfile(user.uid);
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// Creates the login, then the profile (and the institute, when a guru
  /// registers a new one) in one batch. If the batch fails the login is
  /// deleted again so the mobile number can be reused.
  Future<AppUser> signUp(SignupData data) async {
    final mobile = _requireMobile(data.mobile);
    try {
      final authUser = await _auth.createUser(
        email: MobileNumber.authEmail(mobile),
        password: data.password,
      );
      final uid = authUser.uid;

      try {
        final batch = _db.batch();
        String schoolId;
        String schoolName;
        AccountStatus status;

        if (data.registersNewInstitute) {
          // Only a guru may register an institute; they become its owner.
          final ref = _db.collection(FirestorePaths.schools).doc();
          schoolId = ref.id;
          schoolName = data.newInstituteName!.trim();
          status = AccountStatus.approved;
          batch.set(ref, {
            'name': schoolName,
            'city': data.newInstituteCity?.trim(),
            'ownerId': uid,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          schoolId = data.instituteId!;
          schoolName = data.instituteName ?? '';
          status = AccountStatus.pending;
        }

        final profile = AppUser(
          id: uid,
          name: data.name.trim(),
          role: data.role,
          schoolId: schoolId,
          schoolName: schoolName,
          status: status,
          phone: MobileNumber.e164(mobile),
          dob: data.dob,
          gender: data.gender,
          createdAt: DateTime.now(),
        );
        batch.set(_db.doc(FirestorePaths.user(uid)), {
          ...profile.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();

        await _store.putJson(StorageKeys.cachedUser, profile.toJson());
        return profile;
      } catch (e) {
        await _auth.deleteCurrentUser();
        rethrow;
      }
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// Sets a new password for the account with this mobile number.
  /// Runs on the server (Cloud Function `resetPasswordByMobile`), because
  /// only the Admin SDK can change a password for a signed-out user.
  Future<void> resetPassword({required String mobile, required String newPassword}) async {
    final tenDigits = _requireMobile(mobile);
    try {
      await _api.resetPasswordByMobile(mobile: tenDigits, newPassword: newPassword);
    } catch (e) {
      throw _friendly(e);
    }
  }

  /// Profile from the local cache — instant, works offline.
  AppUser? cachedProfile() {
    final json = _store.getMap(StorageKeys.cachedUser);
    return json == null ? null : AppUser.fromJson(json);
  }

  /// Profile from Firestore; refreshes the cache.
  Future<AppUser> fetchProfile(String uid) async {
    try {
      final snap = await _db.doc(FirestorePaths.user(uid)).get();
      final data = snap.data();
      if (data == null) {
        await _auth.signOut();
        throw const AppException(
          'This account has no profile yet. Please sign up again.',
          code: 'no-profile',
        );
      }
      final profile = AppUser.fromMap(uid, data);
      await _store.putJson(StorageKeys.cachedUser, profile.toJson());
      return profile;
    } catch (e) {
      final cached = cachedProfile();
      if (cached != null && cached.id == uid && e is! AppException) return cached;
      throw AppException.from(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _store.clear();
  }

  String _requireMobile(String input) {
    final m = MobileNumber.normalize(input);
    if (m == null) throw const AppException('Enter a valid 10-digit mobile number.');
    return m;
  }

  /// Auth messages worded for mobile-number login instead of email.
  AppException _friendly(Object e) {
    final ex = AppException.from(e);
    switch (ex.code) {
      case 'email-already-in-use':
        return AppException('This mobile number is already registered. Please sign in.', code: ex.code);
      case 'invalid-email':
        return AppException('Enter a valid 10-digit mobile number.', code: ex.code);
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return AppException('Incorrect mobile number or password.', code: ex.code);
      case 'weak-password':
        return AppException('Choose a stronger password (at least 8 characters).', code: ex.code);
      default:
        return ex;
    }
  }
}
