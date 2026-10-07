// TEMPORARY UI preview: boots the app with a fake signed-in guru and
// in-memory data, so screens can be tried without Firebase.
// Delete once `flutterfire configure` is done.
// flutter run -t lib/main_preview.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/flavor.dart';
import 'core/di/locator.dart';
import 'data/models/app_user.dart';
import 'data/models/attendance_record.dart';
import 'data/models/attendance_summary.dart';
import 'data/models/chat.dart';
import 'data/models/chat_message.dart';
import 'data/models/dance_event.dart';
import 'data/models/member.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/directory_repository.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/user_repository.dart';
import 'redux/actions/app_actions.dart';
import 'redux/store.dart';

var _me = const AppUser(
  id: 'preview-user',
  name: 'Preview Guru',
  role: UserRole.guru,
  schoolId: 'preview-school',
  schoolName: 'Preview Natyakosha',
  phone: '+919876543210',
  gender: Gender.female,
);

final _students = [
  for (final (i, n) in ['Ananya Rao', 'Meera Iyer', 'Divya Reddy', 'Kavya Nair', 'అనన్య'].indexed)
    // The last two were added by the guru and have no login.
    AppUser(
      id: 's$i',
      name: n,
      role: UserRole.student,
      schoolId: 'preview-school',
      managed: i >= 3,
      guardianPhone: i == 3 ? '+919812345678' : null,
    ),
];

final _events = <DanceEvent>[
  DanceEvent(
    id: 'e1',
    title: 'Annual Day',
    date: DateTime.now().add(const Duration(days: 3, hours: 2)),
    endsAt: DateTime.now().add(const Duration(days: 3, hours: 5)),
    venue: 'Ravindra Bharathi, Hyderabad',
    organiser: 'Natyakosha',
    participantIds: const ['s0', 's1'],
    fee: EventFeeConfig(amount: 500, dueDate: DateTime.now().add(const Duration(days: 2)), upiId: 'guru@okbank'),
  ),
  DanceEvent(
    id: 'e2',
    title: 'Navaratri Recital',
    date: DateTime.now().add(const Duration(days: 12)),
    venue: 'Temple hall, Vijayawada',
    participantIds: const ['s2'],
  ),
  DanceEvent(
    id: 'e3',
    title: 'Guru Purnima',
    date: DateTime.now().subtract(const Duration(days: 40)),
    venue: 'School hall',
  ),
];

const _teacher = Member(id: 't1', name: 'Teacher Radha', role: UserRole.teacher);

/// Birthdays are set relative to today so the board always has content.
List<Member> _directory() {
  final now = DateTime.now();
  Member withBirthday(Member m, int dayOffset) {
    final d = now.add(Duration(days: dayOffset));
    return Member(id: m.id, name: m.name, role: m.role, birthMonth: d.month, birthDay: d.day, managed: m.managed);
  }

  return [
    Member(id: _me.id, name: _me.name, role: _me.role, birthMonth: now.month, birthDay: now.day),
    _teacher,
    withBirthday(Member.fromUser(_students[0]), 0),
    withBirthday(Member.fromUser(_students[1]), 2),
    withBirthday(Member.fromUser(_students[2]), 5),
    withBirthday(Member.fromUser(_students[3]), -3),
    withBirthday(Member.fromUser(_students[4]), 40),
    // Students the guru adds while trying the preview.
    for (final s in _students.skip(5))
      if (s.status == AccountStatus.approved) Member.fromUser(s),
  ];
}

final _chats = <Chat>[
  Chat(
    id: Chat.directId('preview-user', 't1'),
    type: ChatType.direct,
    memberIds: const ['preview-user', 't1'],
    createdBy: 't1',
    lastMessage: 'Please bring ghungroo tomorrow',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
    lastSenderId: 't1',
  ),
  Chat(
    id: 'g1',
    type: ChatType.group,
    name: 'Batch A',
    memberIds: const ['preview-user', 't1', 's0', 's1'],
    createdBy: 'preview-user',
    lastMessage: 'Rehearsal at 5 PM',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
    lastSenderId: 'preview-user',
  ),
];

final _messages = <String, List<ChatMessage>>{
  Chat.directId('preview-user', 't1'): [
    ChatMessage(
      id: 'm1',
      senderId: 't1',
      senderName: 'Teacher Radha',
      text: 'Please bring ghungroo tomorrow',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ],
  'g1': [
    ChatMessage(
      id: 'm2',
      senderId: 'preview-user',
      senderName: 'Preview Guru',
      text: 'Rehearsal at 5 PM',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ChatMessage(
      id: 'm3',
      senderId: 's0',
      senderName: 'Ananya Rao',
      text: 'Okay guruji 🙏',
      createdAt: DateTime.now().subtract(const Duration(hours: 23)),
    ),
  ],
};

/// A stream that replays the current value to each new listener, then follows [changes].
Stream<T> _live<T>(T Function() current, Stream<void> changes) => Stream<T>.multi((c) {
      c.add(current());
      final sub = changes.listen((_) => c.add(current()));
      c.onCancel = sub.cancel;
    });

final _chatChanges = StreamController<void>.broadcast();

class _FakeDirectoryRepository implements DirectoryRepository {
  @override
  Future<List<Member>> fetchMembers(String schoolId) async => _directory();
  @override
  Future<void> upsertSelf(AppUser user) async {}
}

class _FakeChatRepository implements ChatRepository {
  @override
  Stream<List<Chat>> watchChats(String schoolId, String uid) =>
      _live(() => [..._chats]..sort((a, b) => b.sortTime.compareTo(a.sortTime)), _chatChanges.stream);

  @override
  Stream<List<ChatMessage>> watchMessages(String schoolId, String chatId) => _live(
        () => [...?_messages[chatId]]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        _chatChanges.stream,
      );

  @override
  Future<String> ensureDirectChat({required String schoolId, required String myId, required String otherId}) async {
    final id = Chat.directId(myId, otherId);
    if (!_chats.any((c) => c.id == id)) {
      _chats.add(Chat(id: id, type: ChatType.direct, memberIds: [myId, otherId], createdBy: myId));
      _chatChanges.add(null);
    }
    return id;
  }

  @override
  Future<String> createGroup({
    required String schoolId,
    required String createdBy,
    required String name,
    required List<String> memberIds,
  }) async {
    final id = 'g${_chats.length + 1}';
    _chats.add(Chat(
      id: id,
      type: ChatType.group,
      name: name,
      memberIds: {createdBy, ...memberIds}.toList(),
      createdBy: createdBy,
      createdAt: DateTime.now(),
    ));
    _chatChanges.add(null);
    return id;
  }

  @override
  Future<void> sendMessage({
    required String schoolId,
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    void add(String from, String fromName, String body) {
      final now = DateTime.now();
      (_messages[chatId] ??= []).add(ChatMessage(
        id: 'm${now.microsecondsSinceEpoch}',
        senderId: from,
        senderName: fromName,
        text: body,
        createdAt: now,
      ));
      final i = _chats.indexWhere((c) => c.id == chatId);
      final c = _chats[i];
      _chats[i] = Chat(
        id: c.id,
        type: c.type,
        memberIds: c.memberIds,
        createdBy: c.createdBy,
        name: c.name,
        createdAt: c.createdAt,
        lastMessage: body,
        lastMessageAt: now,
        lastSenderId: from,
      );
      _chatChanges.add(null);
    }

    add(senderId, senderName, text);
    // The teacher answers, to show messages arriving live.
    if (chatId == Chat.directId(_me.id, 't1')) {
      Timer(const Duration(seconds: 2), () => add('t1', 'Teacher Radha', 'Namaskaram! 🙏'));
    }
  }
}

/// A few past class days (students s0..s4), so the summary has numbers.
final _attendance = <String, AttendanceRecord>{
  for (final (i, ago) in [1, 2, 4, 6, 8].indexed)
    AttendanceRecord.docId(DateTime.now().subtract(Duration(days: ago))): AttendanceRecord(
      id: AttendanceRecord.docId(DateTime.now().subtract(Duration(days: ago))),
      batchId: AttendanceRecord.allStudents,
      date: AttendanceRecord.dayOf(DateTime.now().subtract(Duration(days: ago))),
      // s0 always present, s1 misses some, s4 often absent.
      marks: {
        's0': true,
        's1': i != 1,
        's2': i != 2 && i != 3,
        's3': true,
        's4': i.isEven ? false : true,
      },
      markedBy: 'preview-user',
    ),
};

class _FakeAttendanceRepository implements AttendanceRepository {
  @override
  Future<AttendanceRecord?> fetch(String schoolId, DateTime date,
          [String batchId = AttendanceRecord.allStudents]) async =>
      _attendance[AttendanceRecord.docId(date, batchId)];

  @override
  Future<List<AttendanceRecord>> fetchMonth(String schoolId, int year, int month) async => [
        for (final r in _attendance.values)
          if (r.date.year == year && r.date.month == month) r,
      ]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> save(String schoolId, AttendanceRecord record) async {
    _attendance[record.id] = record;
  }

  @override
  Future<List<StudentDay>> fetchStudentMonth(String schoolId, String studentId, int year, int month) async => [
        for (final r in _attendance.values)
          if (r.date.year == year && r.date.month == month && r.marks.containsKey(studentId))
            StudentDay(date: r.date, present: r.marks[studentId]!, batchId: r.batchId),
      ];
}

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get hasSession => true;
  @override
  String? get currentUid => _me.id;
  @override
  Future<AppUser> fetchProfile(String uid) async => _me;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<List<AppUser>> fetchStudents(String schoolId, {String? batchId}) async =>
      [for (final s in _students) if (s.status == AccountStatus.approved) s]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<String> addManagedStudent({
    required AppUser staff,
    required String name,
    DateTime? dob,
    Gender? gender,
    String? guardianPhone,
  }) async {
    final id = 's${_students.length}';
    _students.add(AppUser(
      id: id,
      name: name.trim(),
      role: UserRole.student,
      schoolId: staff.schoolId,
      dob: dob,
      gender: gender,
      guardianPhone: guardianPhone,
      managed: true,
    ));
    return id;
  }

  @override
  Future<void> updateManagedStudent({required AppUser student}) async {
    final i = _students.indexWhere((s) => s.id == student.id);
    if (i >= 0) _students[i] = student;
  }

  @override
  Future<void> removeManagedStudent({required AppUser student}) async {
    final i = _students.indexWhere((s) => s.id == student.id);
    if (i >= 0) {
      _students[i] = AppUser(
        id: student.id,
        name: student.name,
        role: student.role,
        schoolId: student.schoolId,
        status: AccountStatus.inactive,
        managed: true,
      );
    }
  }
  @override
  Future<List<AppUser>> fetchPending(String schoolId) async => const [];
  @override
  Future<void> updateProfile({
    required String uid,
    required String name,
    required DateTime? dob,
    required Gender? gender,
    String? photoUrl,
  }) async {
    _me = _me.copyWith(name: name, dob: dob, gender: gender, photoUrl: photoUrl);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeEventRepository implements EventRepository {
  @override
  Future<List<DanceEvent>> fetchEvents(String schoolId) async => [..._events];

  @override
  Future<String> createEvent({
    required String schoolId,
    required DanceEvent event,
    required List<AppUser> participants,
  }) async {
    final id = 'e${_events.length + 10}';
    _events.add(DanceEvent(
      id: id,
      title: event.title,
      date: event.date,
      endsAt: event.endsAt,
      venue: event.venue,
      organiser: event.organiser,
      description: event.description,
      fee: event.fee,
      groupId: 'g$id',
      participantIds: participants.map((p) => p.id).toList(),
    ));
    return id;
  }

  @override
  Future<void> updateEvent({
    required String schoolId,
    required DanceEvent event,
    required List<AppUser> participants,
  }) async {
    final i = _events.indexWhere((e) => e.id == event.id);
    _events[i] = DanceEvent(
      id: event.id,
      title: event.title,
      date: event.date,
      endsAt: event.endsAt,
      venue: event.venue,
      organiser: event.organiser,
      description: event.description,
      fee: event.fee,
      groupId: event.groupId,
      participantIds: participants.map((p) => p.id).toList(),
    );
  }

  @override
  Future<void> deleteEvent({required String schoolId, required String eventId, String? groupId}) async {
    _events.removeWhere((e) => e.id == eventId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load(Flavor.dev);
  await setupLocator();

  locator
    ..unregister<AuthRepository>()
    ..unregister<UserRepository>()
    ..unregister<EventRepository>()
    ..unregister<DirectoryRepository>()
    ..unregister<ChatRepository>()
    ..unregister<AttendanceRepository>()
    ..registerSingleton<AuthRepository>(_FakeAuthRepository())
    ..registerSingleton<UserRepository>(_FakeUserRepository())
    ..registerSingleton<EventRepository>(_FakeEventRepository())
    ..registerSingleton<DirectoryRepository>(_FakeDirectoryRepository())
    ..registerSingleton<ChatRepository>(_FakeChatRepository())
    ..registerSingleton<AttendanceRepository>(_FakeAttendanceRepository());

  // Every repository above is faked, so treating Firebase as ready is safe.
  final store = createStore();
  store.dispatch(AuthSuccessAction(_me));
  runApp(NatyakoshaApp(store: store));
}
