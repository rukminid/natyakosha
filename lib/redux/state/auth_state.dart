import 'package:equatable/equatable.dart';

import '../../data/models/app_user.dart';

enum AuthStatus {
  /// App just started; splash is checking for a saved session.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.loading = false,
    this.error,
  });

  const AuthState.initial() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final AppUser? user;
  final bool loading;
  final String? error;

  /// Pass `error: () => null` to clear the error.
  AuthState copyWith({
    AuthStatus? status,
    AppUser? Function()? user,
    bool? loading,
    String? Function()? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user != null ? user() : this.user,
        loading: loading ?? this.loading,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [status, user, loading, error];
}
