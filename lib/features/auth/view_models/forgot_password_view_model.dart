import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/auth_thunks.dart' as auth;

/// Forgot password needs no Redux state of its own: the request is a
/// one-off call whose result (error or success) only matters to this screen.
class ForgotPasswordViewModel extends Equatable {
  const ForgotPasswordViewModel({required this.isOnline, required this.resetPassword});

  final bool isOnline;

  /// Returns an error message, or null when the password was changed.
  final Future<String?> Function({required String mobile, required String newPassword})
      resetPassword;

  static ForgotPasswordViewModel fromStore(Store<AppState> store) => ForgotPasswordViewModel(
        isOnline: store.state.isOnline,
        resetPassword: auth.resetPassword,
      );

  @override
  List<Object?> get props => [isOnline];
}
