import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/dance_event.dart';
import '../../../data/models/member.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/chat_thunks.dart' as chat_thunks;
import '../../../redux/thunks/content_thunks.dart';
import '../../../redux/thunks/event_thunks.dart' as ev;
import '../../../redux/thunks/member_thunks.dart' as members;

/// Events tab: the list, the calendar and the staff actions.
class EventsViewModel extends Equatable {
  const EventsViewModel({
    required this.all,
    required this.members,
    required this.upcoming,
    required this.past,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.refresh,
  });

  final List<DanceEvent> all;

  /// Everyone in the school, for the birthday board.
  final List<Member> members;
  final List<DanceEvent> upcoming;
  final List<DanceEvent> past;
  final bool loading;
  final String? error;
  final bool isStaff;
  final Future<void> Function() refresh;

  List<DanceEvent> onDay(DateTime day) => sel.eventsOnDay(all, day);
  List<Member> birthdaysOn(DateTime day) => sel.birthdaysOn(members, day);
  List<Member> birthdaysInMonth(DateTime month) => sel.birthdaysInMonth(members, month.year, month.month);

  static EventsViewModel fromStore(Store<AppState> store) {
    final all = store.state.events.items;
    return EventsViewModel(
      all: all,
      members: store.state.directory.items,
      upcoming: sel.upcomingEvents(store.state),
      past: all.where((e) => !e.isUpcoming).toList(),
      loading: store.state.events.loading,
      error: store.state.events.error,
      isStaff: sel.isStaff(store.state),
      refresh: () async {
        store.dispatch(chat_thunks.loadDirectory());
        await store.dispatch(loadEvents());
      },
    );
  }

  @override
  List<Object?> get props => [all, members, loading, error, isStaff];
}

/// Create / edit form. [eventId] is null for a new event.
class EventFormViewModel extends Equatable {
  const EventFormViewModel({
    required this.event,
    required this.students,
    required this.studentsLoading,
    required this.studentsError,
    required this.isOnline,
    required this.loadStudents,
    required this.save,
  });

  final DanceEvent? event;
  final List<AppUser> students;
  final bool studentsLoading;
  final String? studentsError;
  final bool isOnline;
  final Future<void> Function() loadStudents;

  /// Returns an error message, or null when saved.
  final Future<String?> Function(DanceEvent event, List<AppUser> participants) save;

  static EventFormViewModel fromStore(Store<AppState> store, String? eventId) => EventFormViewModel(
        event: eventId == null ? null : sel.eventById(store.state, eventId),
        students: store.state.students.items,
        studentsLoading: store.state.students.loading,
        studentsError: store.state.students.error,
        isOnline: store.state.isOnline,
        loadStudents: () async => store.dispatch(members.loadStudents()),
        save: (event, participants) async =>
            await store.dispatch(ev.saveEvent(event, participants)) as String?,
      );

  @override
  List<Object?> get props => [event, students, studentsLoading, studentsError, isOnline];
}

/// One event's detail screen.
class EventDetailViewModel extends Equatable {
  const EventDetailViewModel({
    required this.event,
    required this.userId,
    required this.isStaff,
    required this.students,
    required this.loadStudents,
    required this.delete,
  });

  /// Null once the event was deleted (the screen then closes).
  final DanceEvent? event;
  final String userId;
  final bool isStaff;
  final List<AppUser> students;
  final Future<void> Function() loadStudents;

  /// Returns an error message, or null when deleted.
  final Future<String?> Function(DanceEvent event) delete;

  static EventDetailViewModel fromStore(Store<AppState> store, String eventId) => EventDetailViewModel(
        event: sel.eventById(store.state, eventId),
        userId: store.state.auth.user?.id ?? '',
        isStaff: sel.isStaff(store.state),
        students: store.state.students.items,
        loadStudents: () async => store.dispatch(members.loadStudents()),
        delete: (event) async => await store.dispatch(ev.deleteEvent(event)) as String?,
      );

  @override
  List<Object?> get props => [event, userId, isStaff, students];
}
