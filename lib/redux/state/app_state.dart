import 'package:equatable/equatable.dart';

import 'attendance_state.dart';
import 'auth_state.dart';
import 'chat_state.dart';
import 'list_state.dart';
import 'payments_state.dart';
import '../../data/models/announcement.dart';
import '../../data/models/batch.dart';
import '../../data/models/app_user.dart';
import '../../data/models/dance_event.dart';
import '../../data/models/event_fee.dart';
import '../../data/models/event_item.dart';
import '../../data/models/institute.dart';
import '../../data/models/media_item.dart';
import '../../data/models/member.dart';
import '../../data/models/theory_note.dart';

export 'attendance_state.dart';
export 'auth_state.dart';
export 'chat_state.dart';
export 'list_state.dart';
export 'payments_state.dart';

/// The single Redux state tree.
class AppState extends Equatable {
  const AppState({
    required this.auth,
    required this.isOnline,
    required this.firebaseReady,
    required this.payments,
    required this.announcements,
    required this.events,
    required this.eventItems,
    required this.eventFees,
    required this.media,
    required this.theory,
    required this.batches,
    required this.institutes,
    required this.pendingMembers,
    required this.students,
    required this.directory,
    required this.chat,
    required this.attendance,
  });

  factory AppState.initial({bool firebaseReady = true}) => AppState(
        auth: const AuthState.initial(),
        isOnline: true,
        firebaseReady: firebaseReady,
        payments: const PaymentsState.initial(),
        announcements: const ListState<Announcement>.initial(),
        events: const ListState<DanceEvent>.initial(),
        eventItems: const {},
        eventFees: const {},
        media: const ListState<MediaItem>.initial(),
        theory: const ListState<TheoryNote>.initial(),
        batches: const ListState<Batch>.initial(),
        institutes: const ListState<Institute>.initial(),
        pendingMembers: const ListState<AppUser>.initial(),
        students: const ListState<AppUser>.initial(),
        directory: const ListState<Member>.initial(),
        chat: const ChatState.initial(),
        attendance: const AttendanceState.initial(),
      );

  final AuthState auth;
  final bool isOnline;

  /// False when `flutterfire configure` has not been run yet.
  final bool firebaseReady;
  final PaymentsState payments;
  final ListState<Announcement> announcements;
  final ListState<DanceEvent> events;

  /// Running order per event id.
  final Map<String, ListState<EventItem>> eventItems;

  /// Event fees per event id. Staff hold every participant's fee; a student
  /// or parent holds only their own (or their children's).
  final Map<String, ListState<EventFee>> eventFees;

  /// Gallery: the school's photos, videos and audio, newest first.
  final ListState<MediaItem> media;

  /// Theory library notes, by topic.
  final ListState<TheoryNote> theory;

  /// Class batches, by name.
  final ListState<Batch> batches;

  /// Institute dropdown on the sign-up screen.
  final ListState<Institute> institutes;

  /// Staff only: sign-ups waiting for approval.
  final ListState<AppUser> pendingMembers;

  /// Staff only: approved students, for picking event participants.
  final ListState<AppUser> students;

  /// Everyone in the school: chat pickers and the birthday board.
  final ListState<Member> directory;
  final ChatState chat;
  final AttendanceState attendance;

  AppState copyWith({
    AuthState? auth,
    bool? isOnline,
    PaymentsState? payments,
    ListState<Announcement>? announcements,
    ListState<DanceEvent>? events,
    Map<String, ListState<EventItem>>? eventItems,
    Map<String, ListState<EventFee>>? eventFees,
    ListState<MediaItem>? media,
    ListState<TheoryNote>? theory,
    ListState<Batch>? batches,
    ListState<Institute>? institutes,
    ListState<AppUser>? pendingMembers,
    ListState<AppUser>? students,
    ListState<Member>? directory,
    ChatState? chat,
    AttendanceState? attendance,
  }) =>
      AppState(
        auth: auth ?? this.auth,
        isOnline: isOnline ?? this.isOnline,
        firebaseReady: firebaseReady,
        payments: payments ?? this.payments,
        announcements: announcements ?? this.announcements,
        events: events ?? this.events,
        eventItems: eventItems ?? this.eventItems,
        eventFees: eventFees ?? this.eventFees,
        media: media ?? this.media,
        theory: theory ?? this.theory,
        batches: batches ?? this.batches,
        institutes: institutes ?? this.institutes,
        pendingMembers: pendingMembers ?? this.pendingMembers,
        students: students ?? this.students,
        directory: directory ?? this.directory,
        chat: chat ?? this.chat,
        attendance: attendance ?? this.attendance,
      );

  @override
  List<Object?> get props => [auth, isOnline, firebaseReady, payments, announcements, events, eventItems, eventFees, media, theory, batches, institutes, pendingMembers, students, directory, chat, attendance];
}
