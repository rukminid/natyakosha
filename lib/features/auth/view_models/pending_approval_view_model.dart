import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/auth_thunks.dart' as auth;

class PendingApprovalViewModel extends Equatable {
  const PendingApprovalViewModel({
    required this.name,
    required this.instituteName,
    required this.status,
    required this.checkAgain,
    required this.signOut,
  });

  final String name;
  final String instituteName;
  final AccountStatus status;
  final Future<void> Function() checkAgain;
  final void Function() signOut;

  static PendingApprovalViewModel fromStore(Store<AppState> store) {
    final user = store.state.auth.user;
    return PendingApprovalViewModel(
      name: user?.name ?? '',
      instituteName: user?.schoolName ?? 'your institute',
      status: user?.status ?? AccountStatus.pending,
      checkAgain: () async => store.dispatch(auth.refreshProfile()),
      signOut: () => store.dispatch(auth.signOut()),
    );
  }

  @override
  List<Object?> get props => [name, instituteName, status];
}
