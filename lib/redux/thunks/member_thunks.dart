import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/mobile_number.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/institute_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';
import 'chat_thunks.dart' show loadDirectory;

/// Institutes for the sign-up dropdown.
AppThunk loadInstitutes() => (Store<AppState> store) async {
      if (!store.state.firebaseReady) {
        store.dispatch(const InstitutesFailureAction('Firebase is not set up yet.'));
        return;
      }
      store.dispatch(const InstitutesRequestAction());
      try {
        store.dispatch(InstitutesLoadedAction(await locator<InstituteRepository>().fetchActive()));
      } catch (e) {
        store.dispatch(InstitutesFailureAction(AppException.from(e).message));
      }
    };

/// Staff: sign-ups waiting for approval in their institute.
AppThunk loadPendingMembers() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.role.isStaff) return;
      store.dispatch(const PendingMembersRequestAction());
      try {
        final items = await locator<UserRepository>().fetchPending(user.schoolId);
        store.dispatch(PendingMembersLoadedAction(items));
      } catch (e) {
        store.dispatch(PendingMembersFailureAction(AppException.from(e).message));
      }
    };

/// Staff approve or reject a join request. Returns an error message or null.
Future<String?> Function(Store<AppState>) reviewMember(String uid, {required bool approve}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return 'Only your guru can approve members.';
      try {
        await locator<UserRepository>().review(uid: uid, approve: approve, reviewerId: me.id);
        store.dispatch(MemberReviewedAction(uid));
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Staff: approved students of their institute, for the event participant picker.
AppThunk loadStudents() => (Store<AppState> store) async {
      final user = store.state.auth.user;
      if (user == null || !user.role.isStaff) return;
      store.dispatch(const StudentsRequestAction());
      try {
        final items = await locator<UserRepository>().fetchStudents(user.schoolId);
        store.dispatch(StudentsLoadedAction(items));
      } catch (e) {
        store.dispatch(StudentsFailureAction(AppException.from(e).message));
      }
    };

// ---------------------------------------------------------------------------
// Students the guru adds (they may never install the app)
// ---------------------------------------------------------------------------

/// Null when [input] is empty or a valid mobile; otherwise a message.
/// [normalized] receives the E.164 number (or null).
String? _guardianPhone(String? input, void Function(String? e164) normalized) {
  final raw = input?.trim() ?? '';
  if (raw.isEmpty) {
    normalized(null);
    return null;
  }
  final ten = MobileNumber.normalize(raw);
  if (ten == null) return 'Enter a valid 10-digit mobile number.';
  normalized(MobileNumber.e164(ten));
  return null;
}

/// Common checks for add / edit / remove. Returns an error message or null.
String? _canManageStudents(Store<AppState> store) {
  final me = store.state.auth.user;
  if (me == null || !me.role.isStaff) return 'Only your guru or teachers can manage students.';
  if (!store.state.isOnline) return AppException.offline.message;
  return null;
}

/// Another roster student with the same name (ignoring case and spacing).
bool _nameTaken(Store<AppState> store, String name, {String? exceptId}) {
  final wanted = name.trim().toLowerCase();
  return store.state.students.items.any((s) => s.id != exceptId && s.name.trim().toLowerCase() == wanted);
}

const _duplicateMessage =
    'A student with this name is already on the roster. Add a surname or initial to tell them apart.';

/// Staff add a student to the roster. Returns an error message, or null.
Future<String?> Function(Store<AppState>) addStudent({
  required String name,
  DateTime? dob,
  Gender? gender,
  String? guardianMobile,
}) =>
    (Store<AppState> store) async {
      final denied = _canManageStudents(store);
      if (denied != null) return denied;
      String? phone;
      final phoneError = _guardianPhone(guardianMobile, (v) => phone = v);
      if (phoneError != null) return phoneError;
      if (_nameTaken(store, name)) return _duplicateMessage;
      try {
        await locator<UserRepository>().addManagedStudent(
          staff: store.state.auth.user!,
          name: name,
          dob: dob,
          gender: gender,
          guardianPhone: phone,
        );
        await _refreshRoster(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Staff edit a student they added. Students with their own login manage
/// their own profile, so this refuses them.
Future<String?> Function(Store<AppState>) updateStudent(
  AppUser student, {
  required String name,
  DateTime? dob,
  Gender? gender,
  String? guardianMobile,
}) =>
    (Store<AppState> store) async {
      final denied = _canManageStudents(store);
      if (denied != null) return denied;
      if (!student.managed) return '${student.name} manages their own profile.';
      String? phone;
      final phoneError = _guardianPhone(guardianMobile, (v) => phone = v);
      if (phoneError != null) return phoneError;
      if (_nameTaken(store, name, exceptId: student.id)) return _duplicateMessage;
      try {
        await locator<UserRepository>().updateManagedStudent(
          student: AppUser(
            id: student.id,
            name: name.trim(),
            role: student.role,
            schoolId: student.schoolId,
            schoolName: student.schoolName,
            status: student.status,
            dob: dob,
            gender: gender,
            guardianPhone: phone,
            managed: true,
            photoUrl: student.photoUrl,
            createdAt: student.createdAt,
          ),
        );
        await _refreshRoster(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Staff take a student they added off the roster.
Future<String?> Function(Store<AppState>) removeStudent(AppUser student) =>
    (Store<AppState> store) async {
      final denied = _canManageStudents(store);
      if (denied != null) return denied;
      if (!student.managed) return '${student.name} has their own login and cannot be removed here.';
      try {
        await locator<UserRepository>().removeManagedStudent(student: student);
        await _refreshRoster(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

Future<void> _refreshRoster(Store<AppState> store) async {
  await Future.wait<void>([loadStudents()(store), loadDirectory()(store)]);
}
