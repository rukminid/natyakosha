import 'package:redux/redux.dart';

import '../state/app_state.dart';

/// A thunk: a function that receives the store, can dispatch other actions
/// and do async work — exactly like redux-thunk in JS.
///
///   `Future<void> Function(Store<AppState> store)`
///
/// `await store.dispatch(someThunk())` waits for the thunk to finish.
typedef AppThunk = Future<void> Function(Store<AppState> store);

dynamic thunkMiddleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  if (action is AppThunk) return action(store);
  return next(action);
}
