import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/attendance_summary.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/attendance_thunks.dart' as att;
import '../../../redux/thunks/chat_thunks.dart' as chat_thunks;
import '../../../redux/thunks/event_fee_thunks.dart' show feeStudentIds;

/// A student's own attendance (or, for a parent, each child's), one month at a time.
class MyAttendanceViewModel extends Equatable {
  const MyAttendanceViewModel({
    required this.month,
    required this.people,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.load,
  });

  /// The month the store holds, or null before the first load.
  final DateTime? month;

  /// Whose attendance to show: the student, or each child of a parent.
  final List<({String id, String name, StudentMonth data})> people;
  final bool loading;
  final String? error;
  final bool isStaff;
  final Future<void> Function(DateTime month) load;

  static MyAttendanceViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    final me = s.auth.user;
    final names = {for (final m in s.directory.items) m.id: m.name};
    return MyAttendanceViewModel(
      month: s.attendance.myMonthStart,
      people: me == null
          ? const []
          : [
              for (final id in feeStudentIds(me))
                (
                  id: id,
                  name: id == me.id ? me.name : (names[id] ?? 'Your child'),
                  data: StudentMonth(days: s.attendance.myDays[id] ?? const []),
                ),
            ],
      loading: s.attendance.myLoading,
      error: s.attendance.myError,
      isStaff: me?.role.isStaff ?? false,
      load: (month) async {
        store.dispatch(chat_thunks.loadDirectory());
        await att.loadMyAttendance(month.year, month.month)(store);
      },
    );
  }

  @override
  List<Object?> get props => [month, people, loading, error, isStaff];
}
