import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/batch.dart';
import '../../data/repositories/batch_repository.dart';
import '../actions/app_actions.dart';
import '../state/app_state.dart';
import 'member_thunks.dart';

const _staffOnly = 'Only your guru or teacher can manage batches.';

/// Batches are read by staff (attendance, the batch screen); students only
/// see them through attendance, so only staff load the list.
Future<void> Function(Store<AppState>) loadBatches() => (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff || !store.state.firebaseReady) return;
      store.dispatch(const BatchesRequestAction());
      try {
        store.dispatch(BatchesLoadedAction(await locator<BatchRepository>().fetchAll(me.schoolId)));
      } catch (e) {
        store.dispatch(BatchesFailureAction(AppException.from(e).message));
      }
    };

/// Creates a batch (empty id) or edits one. Staff only.
Future<String?> Function(Store<AppState>) saveBatch(Batch batch) => (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      final name = batch.name.trim();
      if (name.isEmpty) return 'Enter a batch name.';
      final clash = store.state.batches.items
          .any((b) => b.id != batch.id && b.name.trim().toLowerCase() == name.toLowerCase());
      if (clash) return 'There is already a batch called “$name”.';
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<BatchRepository>().save(
          me.schoolId,
          Batch(
            id: batch.id,
            name: name,
            level: _blankToNull(batch.level),
            timing: _blankToNull(batch.timing),
            monthlyFee: batch.monthlyFee,
          ),
        );
        await loadBatches()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Deletes a batch and takes its students out of it. Staff only.
Future<String?> Function(Store<AppState>) deleteBatch(Batch batch) => (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<BatchRepository>().delete(me.schoolId, batch.id);
        await Future.wait([loadBatches()(store), loadStudents()(store)]);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Sets who is in [batch] to [memberIds]. Staff only.
Future<String?> Function(Store<AppState>) setBatchMembers(Batch batch, Set<String> memberIds) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      final previous = {
        for (final s in store.state.students.items)
          if (s.batchId == batch.id) s.id,
      };
      try {
        await locator<BatchRepository>().setMembers(batch.id, memberIds: memberIds, previousIds: previous);
        await loadStudents()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
