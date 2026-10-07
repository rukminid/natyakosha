import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/institute.dart';
import '../../../data/models/signup_data.dart';
import '../../../redux/actions/app_actions.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/auth_thunks.dart' as auth;
import '../../../redux/thunks/member_thunks.dart' as members;

class SignupViewModel extends Equatable {
  const SignupViewModel({
    required this.institutes,
    required this.institutesLoading,
    required this.institutesError,
    required this.submitting,
    required this.error,
    required this.isOnline,
    required this.loadInstitutes,
    required this.signUp,
    required this.clearError,
  });

  final List<Institute> institutes;
  final bool institutesLoading;
  final String? institutesError;
  final bool submitting;
  final String? error;
  final bool isOnline;

  final Future<void> Function() loadInstitutes;
  final void Function(SignupData data) signUp;
  final void Function() clearError;

  static SignupViewModel fromStore(Store<AppState> store) => SignupViewModel(
        institutes: store.state.institutes.items,
        institutesLoading: store.state.institutes.loading,
        institutesError: store.state.institutes.error,
        submitting: store.state.auth.loading,
        error: store.state.auth.error,
        isOnline: store.state.isOnline,
        loadInstitutes: () async => store.dispatch(members.loadInstitutes()),
        signUp: (data) => store.dispatch(auth.signUp(data)),
        clearError: () => store.dispatch(const ClearAuthErrorAction()),
      );

  @override
  List<Object?> get props =>
      [institutes, institutesLoading, institutesError, submitting, error, isOnline];
}
