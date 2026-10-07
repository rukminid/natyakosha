import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/signup_data.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/firestore_paths.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/notification_service.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';
import 'chat_thunks.dart';

AuthRepository get _repo => locator<AuthRepository>();

/// Called by the splash screen. Uses the cached profile for an instant,
/// offline-friendly start, then refreshes it from Firestore in the background.
AppThunk restoreSession() => (Store<AppState> store) async {
      if (!store.state.firebaseReady || !_repo.hasSession) {
        store.dispatch(const SignedOutAction());
        return;
      }
      final uid = _repo.currentUid!;
      final cached = _repo.cachedProfile();
      if (cached != null && cached.id == uid) {
        store.dispatch(AuthSuccessAction(cached));
        _refreshProfile(store, uid);
        return;
      }
      try {
        final user = await _repo.fetchProfile(uid);
        store.dispatch(AuthSuccessAction(user));
        _afterSignIn(store, user);
      } catch (e) {
        store.dispatch(AuthFailureAction(AppException.from(e).message));
      }
    };

/// Mobile number + password.
AppThunk signIn(String mobile, String password) => (Store<AppState> store) async {
      if (!_firebaseReady(store)) return;
      store.dispatch(const AuthRequestAction());
      try {
        final user = await _repo.signIn(mobile, password);
        store.dispatch(AuthSuccessAction(user));
        _afterSignIn(store, user);
      } catch (e) {
        store.dispatch(AuthFailureAction(AppException.from(e).message));
      }
    };

/// Creates the account. Joining an existing institute lands on the
/// "waiting for approval" screen; registering a new one goes straight in.
AppThunk signUp(SignupData data) => (Store<AppState> store) async {
      if (!_firebaseReady(store)) return;
      store.dispatch(const AuthRequestAction());
      try {
        final user = await _repo.signUp(data);
        store.dispatch(AuthSuccessAction(user));
        _afterSignIn(store, user);
      } catch (e) {
        store.dispatch(AuthFailureAction(AppException.from(e).message));
      }
    };

/// Re-reads the profile, e.g. from the "waiting for approval" screen.
AppThunk refreshProfile() => (Store<AppState> store) async {
      final uid = _repo.currentUid;
      if (uid == null) return;
      await _refreshProfile(store, uid);
    };

/// Saves the signed-in user's own profile; [localPhotoPath] is a freshly
/// picked image to upload. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) updateProfile({
  required String name,
  required DateTime? dob,
  required Gender? gender,
  String? localPhotoPath,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null) return 'Please sign in again.';
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        String? photoUrl;
        if (localPhotoPath != null) {
          photoUrl = await locator<StorageService>().uploadImage(
            localPath: localPhotoPath,
            storagePath: StoragePaths.profilePhoto(
              me.id,
              'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
        }
        await locator<UserRepository>().updateProfile(
          uid: me.id,
          name: name,
          dob: dob,
          gender: gender,
          photoUrl: photoUrl,
        );
        // Re-read so the offline cache and the store match the server.
        final fresh = await _repo.fetchProfile(me.id);
        store.dispatch(AuthSuccessAction(fresh));
        syncDirectoryEntry(store, fresh);
        if (photoUrl != null && me.photoUrl != null) _deleteQuietly(me.photoUrl!);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

AppThunk signOut() => (Store<AppState> store) async {
      final uid = store.state.auth.user?.id;
      await stopChatListeners()(store);
      if (uid != null) await locator<NotificationService>().unregisterDevice(uid);
      await _repo.signOut();
      store.dispatch(const SignedOutAction());
    };

/// Forgot password: sets [newPassword] for the account with [mobile].
/// Returns null on success or an error message for the screen to show.
Future<String?> resetPassword({required String mobile, required String newPassword}) async {
  try {
    await _repo.resetPassword(mobile: mobile, newPassword: newPassword);
    return null;
  } catch (e) {
    return AppException.from(e).message;
  }
}

bool _firebaseReady(Store<AppState> store) {
  if (store.state.firebaseReady) return true;
  store.dispatch(const AuthFailureAction(
    'Firebase is not set up yet. Run `flutterfire configure` (see README).',
  ));
  return false;
}

Future<void> _refreshProfile(Store<AppState> store, String uid) async {
  try {
    final fresh = await _repo.fetchProfile(uid);
    if (fresh != store.state.auth.user) store.dispatch(AuthSuccessAction(fresh));
    // Also covers accounts created before the directory existed, and
    // people who were just approved.
    syncDirectoryEntry(store, fresh);
  } on AppException catch (e) {
    if (e.code == 'no-profile') store.dispatch(const SignedOutAction());
  } catch (_) {
    // Offline: keep using the cached profile.
  }
}

void _afterSignIn(Store<AppState> store, AppUser user) {
  // Fire-and-forget: notifications must never block the UI.
  locator<NotificationService>().registerDevice(user.id);
  syncDirectoryEntry(store, user);
}

/// Removes a replaced profile photo; a failure only leaves an orphan file.
void _deleteQuietly(String url) {
  locator<StorageService>().deleteByUrl(url).catchError((Object _) {});
}
