import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/batch.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/batch_thunks.dart' as thunks;
import '../../../redux/thunks/member_thunks.dart' as members;

/// Class batches and who is in each. Staff only.
class BatchesViewModel extends Equatable {
  const BatchesViewModel({
    required this.batches,
    required this.students,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.refresh,
    required this.save,
    required this.delete,
    required this.setMembers,
  });

  final List<Batch> batches;

  /// Approved students, to pick batch members from.
  final List<AppUser> students;
  final bool loading;
  final String? error;
  final bool isStaff;
  final Future<void> Function() refresh;

  /// Each command returns an error message, or null on success.
  final Future<String?> Function(Batch batch) save;
  final Future<String?> Function(Batch batch) delete;
  final Future<String?> Function(Batch batch, Set<String> memberIds) setMembers;

  List<AppUser> membersOf(Batch b) => [for (final s in students) if (s.batchId == b.id) s];

  static BatchesViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    return BatchesViewModel(
      batches: s.batches.items,
      students: s.students.items,
      loading: s.batches.loading || s.students.loading,
      error: s.batches.error,
      isStaff: sel.isStaff(s),
      refresh: () async {
        await Future.wait([thunks.loadBatches()(store), members.loadStudents()(store)]);
      },
      save: (b) => thunks.saveBatch(b)(store),
      delete: (b) => thunks.deleteBatch(b)(store),
      setMembers: (b, ids) => thunks.setBatchMembers(b, ids)(store),
    );
  }

  @override
  List<Object?> get props => [batches, students, loading, error, isStaff];
}
