import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/auth_thunks.dart' as auth;

class ProfileViewModel extends Equatable {
  const ProfileViewModel({
    required this.user,
    required this.isOnline,
    required this.updateProfile,
    required this.signOut,
  });

  final AppUser user;
  final bool isOnline;

  /// Returns an error message, or null when saved.
  final Future<String?> Function({
    required String name,
    required DateTime? dob,
    required Gender? gender,
    String? localPhotoPath,
  }) updateProfile;
  final void Function() signOut;

  static ProfileViewModel fromStore(Store<AppState> store) => ProfileViewModel(
        user: store.state.auth.user!,
        isOnline: store.state.isOnline,
        updateProfile: ({required name, required dob, required gender, localPhotoPath}) async =>
            await store.dispatch(auth.updateProfile(
          name: name,
          dob: dob,
          gender: gender,
          localPhotoPath: localPhotoPath,
        )) as String?,
        signOut: () => store.dispatch(auth.signOut()),
      );

  @override
  List<Object?> get props => [user, isOnline];
}
