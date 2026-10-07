import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/dance_event.dart';
import '../../data/repositories/event_repository.dart';
import '../selectors/selectors.dart';
import '../state/app_state.dart';
import 'content_thunks.dart';

/// Creates a new event, or edits it when [event].id is not empty.
/// Staff only. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) saveEvent(
  DanceEvent event,
  List<AppUser> participants,
) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return 'Only your guru or teacher can manage events.';
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        final repo = locator<EventRepository>();
        if (event.id.isEmpty) {
          await repo.createEvent(schoolId: me.schoolId, event: event, participants: participants);
        } else {
          await repo.updateEvent(schoolId: me.schoolId, event: event, participants: participants);
          // Dancers taken off the event also come off its songs.
          final before = eventById(store.state, event.id)?.participantIds ?? const <String>[];
          final removed = before.toSet()..removeAll(participants.map((p) => p.id));
          await repo.removePerformers(me.schoolId, event.id, removed);
        }
        await loadEvents()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Staff only. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) deleteEvent(DanceEvent event) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return 'Only your guru or teacher can manage events.';
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<EventRepository>().deleteEvent(
          schoolId: me.schoolId,
          eventId: event.id,
          groupId: event.groupId,
        );
        await loadEvents()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };
