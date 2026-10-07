import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/di/locator.dart';
import 'package:natyakosha/core/validators/app_validators.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/member.dart';
import 'package:natyakosha/data/repositories/directory_repository.dart';
import 'package:natyakosha/data/repositories/user_repository.dart';
import 'package:natyakosha/features/chat/view_models/chat_view_models.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/middleware/thunk_middleware.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/state/app_state.dart';
import 'package:natyakosha/redux/thunks/member_thunks.dart';
import 'package:redux/redux.dart';

const _guru = AppUser(id: 'g1', name: 'Guru', role: UserRole.guru, schoolId: 'sc', schoolName: 'Natyakosha');
const _studentUser = AppUser(id: 'st1', name: 'Login Student', role: UserRole.student, schoolId: 'sc');

AppUser _managed(String id, String name) =>
    AppUser(id: id, name: name, role: UserRole.student, schoolId: 'sc', managed: true);

class _FakeUsers implements UserRepository {
  final added = <Map<String, Object?>>[];
  final removed = <String>[];
  final updated = <AppUser>[];

  @override
  Future<String> addManagedStudent({
    required AppUser staff,
    required String name,
    DateTime? dob,
    Gender? gender,
    String? guardianPhone,
  }) async {
    added.add({'staff': staff.id, 'name': name, 'dob': dob, 'gender': gender, 'phone': guardianPhone});
    return 'new1';
  }

  @override
  Future<void> updateManagedStudent({required AppUser student}) async => updated.add(student);

  @override
  Future<void> removeManagedStudent({required AppUser student}) async => removed.add(student.id);

  @override
  Future<List<AppUser>> fetchStudents(String schoolId, {String? batchId}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeDirectory implements DirectoryRepository {
  @override
  Future<List<Member>> fetchMembers(String schoolId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Store<AppState> _store(AppUser user, {List<AppUser> roster = const []}) {
  final store = Store<AppState>(appReducer, initialState: AppState.initial(), middleware: [thunkMiddleware]);
  store.dispatch(AuthSuccessAction(user));
  store.dispatch(StudentsLoadedAction(roster));
  return store;
}

void main() {
  group('guru-added students: model', () {
    test('managed and guardianPhone survive the cache and Firestore maps', () {
      const s = AppUser(
        id: 'm1',
        name: 'Ananya',
        role: UserRole.student,
        schoolId: 'sc',
        managed: true,
        guardianPhone: '+919876543210',
      );
      for (final back in [AppUser.fromMap('m1', s.toMap()), AppUser.fromJson(s.toJson())]) {
        expect(back.managed, isTrue);
        expect(back.guardianPhone, '+919876543210');
      }
    });

    test('accounts without the field are not managed', () {
      expect(AppUser.fromMap('u', {'name': 'A', 'role': 'student', 'schoolId': 's'}).managed, isFalse);
    });

    test('a removed student is not approved', () {
      expect(_managed('m', 'A').copyWith(status: AccountStatus.inactive).isApproved, isFalse);
      expect(AccountStatus.inactive.label, 'Removed');
    });

    test('directory entry carries managed only when true', () {
      expect(Member.fromUser(_managed('m', 'Ananya')).toMap()['managed'], isTrue);
      expect(Member.fromUser(_studentUser).toMap().containsKey('managed'), isFalse);
    });
  });

  group('optionalIndianPhone', () {
    final v = AppValidators.optionalIndianPhone();
    test('allows empty', () => expect(v(''), isNull));
    test('allows a valid number', () => expect(v('98765 43210'), isNull));
    test('rejects a bad number', () => expect(v('12345'), isNotNull));
  });

  group('managing students', () {
    late _FakeUsers users;

    setUp(() {
      users = _FakeUsers();
      locator
        ..registerSingleton<UserRepository>(users)
        ..registerSingleton<DirectoryRepository>(_FakeDirectory());
    });
    tearDown(() => locator.reset());

    test('a student cannot add students', () async {
      final store = _store(_studentUser);
      final error = await store.dispatch(addStudent(name: 'New Kid')) as String?;
      expect(error, contains('Only'));
      expect(users.added, isEmpty);
    });

    test('adding while offline is refused', () async {
      final store = _store(_guru);
      store.dispatch(const SetConnectivityAction(isOnline: false));
      final error = await store.dispatch(addStudent(name: 'New Kid')) as String?;
      expect(error, contains('offline'));
      expect(users.added, isEmpty);
    });

    test('the guru can add a student with only a name', () async {
      final store = _store(_guru);
      final error = await store.dispatch(addStudent(name: '  New Kid ')) as String?;
      expect(error, isNull);
      expect(users.added.single['name'], '  New Kid ');
      expect(users.added.single['staff'], 'g1');
      expect(users.added.single['phone'], isNull);
    });

    test('a parent mobile is stored in E.164 form', () async {
      final store = _store(_guru);
      await store.dispatch(addStudent(name: 'New Kid', guardianMobile: '98765 43210'));
      expect(users.added.single['phone'], '+919876543210');
    });

    test('an invalid parent mobile is refused', () async {
      final store = _store(_guru);
      final error = await store.dispatch(addStudent(name: 'New Kid', guardianMobile: '123')) as String?;
      expect(error, contains('valid'));
      expect(users.added, isEmpty);
    });

    test('a name already on the roster is refused, ignoring case', () async {
      final store = _store(_guru, roster: [_managed('m1', 'Ananya Rao')]);
      final error = await store.dispatch(addStudent(name: ' ananya rao ')) as String?;
      expect(error, contains('already on the roster'));
      expect(users.added, isEmpty);
    });

    test('editing keeps the same name without a duplicate error', () async {
      final ananya = _managed('m1', 'Ananya Rao');
      final store = _store(_guru, roster: [ananya]);
      final error = await store.dispatch(updateStudent(ananya, name: 'Ananya Rao', gender: Gender.female)) as String?;
      expect(error, isNull);
      expect(users.updated.single.gender, Gender.female);
      expect(users.updated.single.managed, isTrue);
    });

    test('students with their own login cannot be edited or removed by staff', () async {
      final store = _store(_guru, roster: [_studentUser]);
      final edit = await store.dispatch(updateStudent(_studentUser, name: 'Other')) as String?;
      final remove = await store.dispatch(removeStudent(_studentUser)) as String?;
      expect(edit, contains('their own profile'));
      expect(remove, contains('own login'));
      expect(users.updated, isEmpty);
      expect(users.removed, isEmpty);
    });

    test('the guru can remove a student they added', () async {
      final ananya = _managed('m1', 'Ananya Rao');
      final store = _store(_guru, roster: [ananya]);
      final error = await store.dispatch(removeStudent(ananya)) as String?;
      expect(error, isNull);
      expect(users.removed, ['m1']);
    });
  });

  group('chat picker', () {
    test('does not offer students who have no login', () {
      final store = _store(_guru);
      store.dispatch(const DirectoryLoadedAction([
        Member(id: 't1', name: 'Teacher', role: UserRole.teacher),
        Member(id: 'a', name: 'On App', role: UserRole.student),
        Member(id: 'm', name: 'Not On App', role: UserRole.student, managed: true),
      ]));
      final names = PeopleViewModel.fromStore(store).people.map((m) => m.name);
      expect(names, ['Teacher', 'On App']);
    });
  });
}
