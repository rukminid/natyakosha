import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/member_thunks.dart' as members;

/// The Students screen: the roster, and add / edit / remove for staff.
class StudentsViewModel extends Equatable {
  const StudentsViewModel({
    required this.students,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.isOnline,
    required this.refresh,
    required this.add,
    required this.update,
    required this.remove,
  });

  final List<AppUser> students;
  final bool loading;
  final String? error;
  final bool isStaff;
  final bool isOnline;
  final Future<void> Function() refresh;

  /// Each returns an error message, or null on success.
  final Future<String?> Function({
    required String name,
    DateTime? dob,
    Gender? gender,
    String? guardianMobile,
  }) add;
  final Future<String?> Function(
    AppUser student, {
    required String name,
    DateTime? dob,
    Gender? gender,
    String? guardianMobile,
  }) update;
  final Future<String?> Function(AppUser student) remove;

  AppUser? studentById(String id) {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  static StudentsViewModel fromStore(Store<AppState> store) => StudentsViewModel(
        students: store.state.students.items,
        loading: store.state.students.loading,
        error: store.state.students.error,
        isStaff: sel.isStaff(store.state),
        isOnline: store.state.isOnline,
        refresh: () async => store.dispatch(members.loadStudents()),
        add: ({required name, dob, gender, guardianMobile}) async => await store.dispatch(
          members.addStudent(name: name, dob: dob, gender: gender, guardianMobile: guardianMobile),
        ) as String?,
        update: (student, {required name, dob, gender, guardianMobile}) async => await store.dispatch(
          members.updateStudent(student, name: name, dob: dob, gender: gender, guardianMobile: guardianMobile),
        ) as String?,
        remove: (student) async => await store.dispatch(members.removeStudent(student)) as String?,
      );

  @override
  List<Object?> get props => [students, loading, error, isStaff, isOnline];
}
