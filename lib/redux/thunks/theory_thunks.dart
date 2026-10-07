import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/theory_note.dart';
import '../../data/repositories/theory_repository.dart';
import '../actions/app_actions.dart';
import '../state/app_state.dart';

const _staffOnly = 'Only your guru or teacher can edit the theory library.';
const maxTheoryImages = 6;

Future<void> Function(Store<AppState>) loadTheory() => (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.isApproved || !store.state.firebaseReady) return;
      store.dispatch(const TheoryRequestAction());
      try {
        store.dispatch(TheoryLoadedAction(await locator<TheoryRepository>().fetchAll(me.schoolId)));
      } catch (e) {
        store.dispatch(TheoryFailureAction(AppException.from(e).message));
      }
    };

/// Creates a note (empty id) or edits one. Staff only.
/// Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) saveTheoryNote(
  TheoryNote note, {
  List<String> newImagePaths = const [],
  List<String> removedUrls = const [],
  void Function(double progress)? onProgress,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      final clean = note.copyWith(
        topic: note.topic.trim(),
        title: note.title.trim(),
        body: note.body.trim(),
      );
      if (clean.topic.isEmpty) return 'Choose or type a topic.';
      if (clean.title.isEmpty) return 'Enter a title.';
      if (clean.body.isEmpty && clean.imageUrls.length + newImagePaths.length - removedUrls.length <= 0) {
        return 'Write something or add a picture.';
      }
      if (clean.imageUrls.length - removedUrls.length + newImagePaths.length > maxTheoryImages) {
        return 'A note can have up to $maxTheoryImages pictures.';
      }
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<TheoryRepository>().save(
          schoolId: me.schoolId,
          note: clean,
          newImagePaths: newImagePaths,
          removedUrls: removedUrls,
          onProgress: onProgress,
        );
        await loadTheory()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Staff only. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) deleteTheoryNote(TheoryNote note) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<TheoryRepository>().delete(me.schoolId, note);
        await loadTheory()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };
