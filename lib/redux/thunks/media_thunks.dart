import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/media_item.dart';
import '../../data/repositories/media_repository.dart';
import '../actions/app_actions.dart';
import '../state/app_state.dart';

const _staffOnly = 'Only your guru or teacher can manage the gallery.';

Future<void> Function(Store<AppState>) loadMedia() => (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.isApproved || !store.state.firebaseReady) return;
      store.dispatch(const MediaRequestAction());
      try {
        store.dispatch(MediaLoadedAction(await locator<MediaRepository>().fetchMedia(me.schoolId)));
      } catch (e) {
        store.dispatch(MediaFailureAction(AppException.from(e).message));
      }
    };

/// Uploads [paths] one after another to [eventId], then reloads the gallery.
/// [onProgress] gets (files done, files total, progress of the current file).
/// Staff only. Returns an error message, or null when every file went up;
/// when one fails the rest are skipped and the ones already uploaded stay.
Future<String?> Function(Store<AppState>) uploadMedia({
  required String eventId,
  required MediaType type,
  required List<String> paths,
  String? itemId,
  String? caption,
  void Function(int done, int total, double current)? onProgress,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (paths.isEmpty) return 'Choose at least one file.';
      if (!store.state.isOnline) return AppException.offline.message;
      final repo = locator<MediaRepository>();
      String? error;
      for (var i = 0; i < paths.length; i++) {
        try {
          await repo.upload(
            schoolId: me.schoolId,
            uploadedBy: me.id,
            eventId: eventId,
            type: type,
            localPath: paths[i],
            itemId: itemId,
            caption: caption,
            onProgress: (p) => onProgress?.call(i, paths.length, p),
          );
          onProgress?.call(i + 1, paths.length, 0);
        } catch (e) {
          error = i == 0
              ? AppException.from(e).message
              : '${AppException.from(e).message} ($i of ${paths.length} uploaded)';
          break;
        }
      }
      await loadMedia()(store);
      return error;
    };

/// Staff only. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) deleteMedia(MediaItem item) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<MediaRepository>().delete(me.schoolId, item);
        await loadMedia()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };
