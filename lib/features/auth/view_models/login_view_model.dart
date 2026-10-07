import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../redux/actions/app_actions.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/auth_thunks.dart' as auth;

class LoginViewModel extends Equatable {
  const LoginViewModel({
    required this.loading,
    required this.error,
    required this.isOnline,
    required this.firebaseReady,
    required this.signIn,
    required this.clearError,
  });

  final bool loading;
  final String? error;
  final bool isOnline;
  final bool firebaseReady;

  final void Function(String mobile, String password) signIn;
  final void Function() clearError;

  static LoginViewModel fromStore(Store<AppState> store) => LoginViewModel(
        loading: store.state.auth.loading,
        error: store.state.auth.error,
        isOnline: store.state.isOnline,
        firebaseReady: store.state.firebaseReady,
        signIn: (mobile, password) => store.dispatch(auth.signIn(mobile, password)),
        clearError: () => store.dispatch(const ClearAuthErrorAction()),
      );

  @override
  List<Object?> get props => [loading, error, isOnline, firebaseReady];
}
