import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/auth_thunks.dart';

/// MVVM: the ViewModel exposes only what the view needs from the store,
/// plus the commands (callbacks) the view can trigger.
class SplashViewModel extends Equatable {
  const SplashViewModel({required this.firebaseReady, required this.restore});

  final bool firebaseReady;
  final Future<void> Function() restore;

  static SplashViewModel fromStore(Store<AppState> store) => SplashViewModel(
        firebaseReady: store.state.firebaseReady,
        restore: () async => store.dispatch(restoreSession()),
      );

  @override
  List<Object?> get props => [firebaseReady];
}
