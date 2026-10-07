import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/event_item.dart';
import '../../data/repositories/event_repository.dart';
import '../actions/app_actions.dart';
import '../selectors/selectors.dart';
import '../state/app_state.dart';

const _staffOnly = 'Only your guru or teacher can edit the running order.';

/// Loads one event's running order into `eventItems[eventId]`.
Future<void> Function(Store<AppState>) loadEventItems(String eventId) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null) return;
      store.dispatch(EventItemsRequestAction(eventId));
      try {
        final items = await locator<EventRepository>().fetchItems(me.schoolId, eventId);
        store.dispatch(EventItemsLoadedAction(eventId, items));
      } catch (e) {
        store.dispatch(EventItemsFailureAction(eventId, AppException.from(e).message));
      }
    };

/// Adds a song, or edits it when [item].id is not empty. Staff only.
/// Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) saveEventItem(String eventId, EventItem item) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        final repo = locator<EventRepository>();
        if (item.id.isEmpty) {
          await repo.addItem(me.schoolId, eventId, item);
        } else {
          await repo.updateItem(me.schoolId, eventId, item);
        }
        await loadEventItems(eventId)(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Deletes a song and renumbers the rest. Staff only.
Future<String?> Function(Store<AppState>) deleteEventItem(String eventId, EventItem item) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        final remaining =
            itemsForEvent(store.state, eventId).where((i) => i.id != item.id).toList();
        await locator<EventRepository>().deleteItem(me.schoolId, eventId, item.id, remaining);
        await loadEventItems(eventId)(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Applies [reordered] straight away, then saves it. On failure the saved
/// order is reloaded so the screen snaps back. Staff only.
Future<String?> Function(Store<AppState>) reorderEventItems(
  String eventId,
  List<EventItem> reordered,
) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      final numbered = [
        for (var i = 0; i < reordered.length; i++) reordered[i].copyWith(order: i + 1),
      ];
      store.dispatch(EventItemsLoadedAction(eventId, numbered));
      try {
        await locator<EventRepository>().reorderItems(me.schoolId, eventId, numbered);
        return null;
      } catch (e) {
        await loadEventItems(eventId)(store);
        return AppException.from(e).message;
      }
    };
