import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/theory_note.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/theory_thunks.dart' as thunks;

/// Theory library: everyone reads, staff add, edit and delete.
class TheoryViewModel extends Equatable {
  const TheoryViewModel({
    required this.notes,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.refresh,
    required this.save,
    required this.delete,
  });

  final List<TheoryNote> notes;
  final bool loading;
  final String? error;
  final bool isStaff;
  final Future<void> Function() refresh;

  /// Each command returns an error message, or null on success.
  final Future<String?> Function(
    TheoryNote note, {
    List<String> newImagePaths,
    List<String> removedUrls,
    void Function(double progress)? onProgress,
  }) save;
  final Future<String?> Function(TheoryNote note) delete;

  List<String> get topics => sel.theoryTopics(notes);

  TheoryNote? byId(String id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  static TheoryViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    return TheoryViewModel(
      notes: s.theory.items,
      loading: s.theory.loading,
      error: s.theory.error,
      isStaff: sel.isStaff(s),
      refresh: () => thunks.loadTheory()(store),
      save: (note, {newImagePaths = const [], removedUrls = const [], onProgress}) => thunks.saveTheoryNote(
        note,
        newImagePaths: newImagePaths,
        removedUrls: removedUrls,
        onProgress: onProgress,
      )(store),
      delete: (note) => thunks.deleteTheoryNote(note)(store),
    );
  }

  @override
  List<Object?> get props => [notes, loading, error, isStaff];
}
