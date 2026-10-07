import 'package:redux/redux.dart';

import '../../data/models/announcement.dart';
import '../../data/models/app_user.dart';
import '../../data/models/batch.dart';
import '../../data/models/dance_event.dart';
import '../../data/models/event_fee.dart';
import '../../data/models/event_item.dart';
import '../../data/models/institute.dart';
import '../../data/models/media_item.dart';
import '../../data/models/member.dart';
import '../../data/models/theory_note.dart';
import '../actions/app_actions.dart';
import '../state/app_state.dart';
import 'attendance_reducer.dart';
import 'auth_reducer.dart';
import 'chat_reducer.dart';
import 'payments_reducer.dart';

/// Root reducer — like `combineReducers` in JS Redux.
AppState appReducer(AppState state, dynamic action) {
  // Signing out resets every slice so no data leaks between accounts.
  if (action is SignedOutAction) {
    return AppState.initial(firebaseReady: state.firebaseReady).copyWith(
      isOnline: state.isOnline,
      auth: const AuthState(status: AuthStatus.unauthenticated),
    );
  }
  return state.copyWith(
    auth: authReducer(state.auth, action),
    isOnline: _connectivityReducer(state.isOnline, action),
    payments: paymentsReducer(state.payments, action),
    announcements: _announcementsReducer(state.announcements, action),
    events: _eventsReducer(state.events, action),
    eventItems: _eventItemsReducer(state.eventItems, action),
    eventFees: _eventFeesReducer(state.eventFees, action),
    media: _mediaReducer(state.media, action),
    theory: _theoryReducer(state.theory, action),
    batches: _batchesReducer(state.batches, action),
    institutes: _institutesReducer(state.institutes, action),
    pendingMembers: _pendingMembersReducer(state.pendingMembers, action),
    students: _studentsReducer(state.students, action),
    directory: _directoryReducer(state.directory, action),
    chat: chatReducer(state.chat, action),
    attendance: attendanceReducer(state.attendance, action),
  );
}

final _connectivityReducer = combineReducers<bool>([
  TypedReducer<bool, SetConnectivityAction>((_, a) => a.isOnline).call,
]);

final _announcementsReducer = combineReducers<ListState<Announcement>>([
  TypedReducer<ListState<Announcement>, AnnouncementsRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<Announcement>, AnnouncementsLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<Announcement>, AnnouncementsFailureAction>((s, a) => s.failed(a.message)).call,
]);

final _eventsReducer = combineReducers<ListState<DanceEvent>>([
  TypedReducer<ListState<DanceEvent>, EventsRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<DanceEvent>, EventsLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<DanceEvent>, EventsFailureAction>((s, a) => s.failed(a.message)).call,
]);

Map<String, ListState<EventItem>> _eventItemsReducer(
  Map<String, ListState<EventItem>> state,
  dynamic action,
) {
  if (action is EventItemsRequestAction) {
    final cur = state[action.eventId] ?? const ListState<EventItem>.initial();
    return {...state, action.eventId: cur.startLoading()};
  }
  if (action is EventItemsLoadedAction) {
    final cur = state[action.eventId] ?? const ListState<EventItem>.initial();
    return {...state, action.eventId: cur.loaded(action.items)};
  }
  if (action is EventItemsFailureAction) {
    final cur = state[action.eventId] ?? const ListState<EventItem>.initial();
    return {...state, action.eventId: cur.failed(action.message)};
  }
  return state;
}

Map<String, ListState<EventFee>> _eventFeesReducer(
  Map<String, ListState<EventFee>> state,
  dynamic action,
) {
  if (action is EventFeesRequestAction) {
    final cur = state[action.eventId] ?? const ListState<EventFee>.initial();
    return {...state, action.eventId: cur.startLoading()};
  }
  if (action is EventFeesLoadedAction) {
    final cur = state[action.eventId] ?? const ListState<EventFee>.initial();
    return {...state, action.eventId: cur.loaded(action.items)};
  }
  if (action is EventFeesFailureAction) {
    final cur = state[action.eventId] ?? const ListState<EventFee>.initial();
    return {...state, action.eventId: cur.failed(action.message)};
  }
  return state;
}

final _mediaReducer = combineReducers<ListState<MediaItem>>([
  TypedReducer<ListState<MediaItem>, MediaRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<MediaItem>, MediaLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<MediaItem>, MediaFailureAction>((s, a) => s.failed(a.message)).call,
]);

final _theoryReducer = combineReducers<ListState<TheoryNote>>([
  TypedReducer<ListState<TheoryNote>, TheoryRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<TheoryNote>, TheoryLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<TheoryNote>, TheoryFailureAction>((s, a) => s.failed(a.message)).call,
]);

final _batchesReducer = combineReducers<ListState<Batch>>([
  TypedReducer<ListState<Batch>, BatchesRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<Batch>, BatchesLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<Batch>, BatchesFailureAction>((s, a) => s.failed(a.message)).call,
]);

final _institutesReducer = combineReducers<ListState<Institute>>([
  TypedReducer<ListState<Institute>, InstitutesRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<Institute>, InstitutesLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<Institute>, InstitutesFailureAction>((s, a) => s.failed(a.message)).call,
]);

final _pendingMembersReducer = combineReducers<ListState<AppUser>>([
  TypedReducer<ListState<AppUser>, PendingMembersRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<AppUser>, PendingMembersLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<AppUser>, PendingMembersFailureAction>((s, a) => s.failed(a.message)).call,
  TypedReducer<ListState<AppUser>, MemberReviewedAction>(
    (s, a) => s.loaded(s.items.where((u) => u.id != a.uid).toList()),
  ).call,
]);

final _studentsReducer = combineReducers<ListState<AppUser>>([
  TypedReducer<ListState<AppUser>, StudentsRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<AppUser>, StudentsLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<AppUser>, StudentsFailureAction>((s, a) => s.failed(a.message)).call,
]);

final _directoryReducer = combineReducers<ListState<Member>>([
  TypedReducer<ListState<Member>, DirectoryRequestAction>((s, _) => s.startLoading()).call,
  TypedReducer<ListState<Member>, DirectoryLoadedAction>((s, a) => s.loaded(a.items)).call,
  TypedReducer<ListState<Member>, DirectoryFailureAction>((s, a) => s.failed(a.message)).call,
]);
