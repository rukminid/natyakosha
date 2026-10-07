import 'package:redux/redux.dart';

import '../actions/app_actions.dart';
import '../state/auth_state.dart';

final authReducer = combineReducers<AuthState>([
  TypedReducer<AuthState, AuthRequestAction>(
    (s, _) => s.copyWith(loading: true, error: () => null),
  ).call,
  TypedReducer<AuthState, AuthSuccessAction>(
    (s, a) => AuthState(status: AuthStatus.authenticated, user: a.user),
  ).call,
  TypedReducer<AuthState, AuthFailureAction>(
    (s, a) => AuthState(status: AuthStatus.unauthenticated, error: a.message),
  ).call,
  TypedReducer<AuthState, ClearAuthErrorAction>(
    (s, _) => s.copyWith(error: () => null),
  ).call,
]);
