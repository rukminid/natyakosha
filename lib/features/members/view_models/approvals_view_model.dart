import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/member_thunks.dart' as members;

/// Guru: people who signed up for this institute and wait for approval.
class ApprovalsViewModel extends Equatable {
  const ApprovalsViewModel({
    required this.pending,
    required this.loading,
    required this.error,
    required this.isOnline,
    required this.refresh,
    required this.review,
  });

  final List<AppUser> pending;
  final bool loading;
  final String? error;
  final bool isOnline;
  final Future<void> Function() refresh;

  /// Returns an error message, or null on success.
  final Future<String?> Function(String uid, {required bool approve}) review;

  static ApprovalsViewModel fromStore(Store<AppState> store) => ApprovalsViewModel(
        pending: store.state.pendingMembers.items,
        loading: store.state.pendingMembers.loading,
        error: store.state.pendingMembers.error,
        isOnline: store.state.isOnline,
        refresh: () async => store.dispatch(members.loadPendingMembers()),
        review: (uid, {required approve}) async =>
            await store.dispatch(members.reviewMember(uid, approve: approve)) as String?,
      );

  @override
  List<Object?> get props => [pending, loading, error, isOnline];
}
