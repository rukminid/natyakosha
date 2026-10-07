import 'package:redux/redux.dart';

import '../core/config/env.dart';
import 'middleware/logger_middleware.dart';
import 'middleware/thunk_middleware.dart';
import 'reducers/app_reducer.dart';
import 'state/app_state.dart';

Store<AppState> createStore({bool firebaseReady = true}) => Store<AppState>(
      appReducer,
      initialState: AppState.initial(firebaseReady: firebaseReady),
      middleware: [
        thunkMiddleware,
        if (Env.enableLogs) loggerMiddleware,
      ],
      distinct: true,
    );
