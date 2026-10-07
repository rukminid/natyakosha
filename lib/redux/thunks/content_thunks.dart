import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';
import 'member_thunks.dart';
import 'payment_thunks.dart';

AppThunk loadAnnouncements() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null) return;
      store.dispatch(const AnnouncementsRequestAction());
      try {
        final items = await locator<AnnouncementRepository>().fetchLatest(user.schoolId);
        store.dispatch(AnnouncementsLoadedAction(items));
      } catch (e) {
        store.dispatch(AnnouncementsFailureAction(AppException.from(e).message));
      }
    };

AppThunk loadEvents() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null) return;
      store.dispatch(const EventsRequestAction());
      try {
        final items = await locator<EventRepository>().fetchEvents(user.schoolId);
        store.dispatch(EventsLoadedAction(items));
      } catch (e) {
        store.dispatch(EventsFailureAction(AppException.from(e).message));
      }
    };

/// Everything the dashboard needs, loaded in parallel.
AppThunk loadDashboard() => (Store<AppState> store) async {
      await Future.wait<void>([
        loadAnnouncements()(store),
        loadEvents()(store),
        loadPayments()(store),
        loadPendingMembers()(store),
      ]);
    };
