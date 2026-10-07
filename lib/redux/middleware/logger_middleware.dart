import 'package:redux/redux.dart';

import '../../core/utils/app_logger.dart';
import '../actions/app_actions.dart';
import '../middleware/thunk_middleware.dart';
import '../state/app_state.dart';

/// Logs every plain action (not thunks) in debug builds — a lightweight
/// stand-in for redux-logger / Reactotron.
dynamic loggerMiddleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  if (action is! AppThunk && action is! PaymentUploadProgressAction) {
    AppLogger.d('⚡ ${action.runtimeType}');
  }
  return next(action);
}
