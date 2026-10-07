import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Equivalent of @react-native-community/netinfo.
///
/// `connectivity_plus` tells us whether Wi-Fi / mobile data is on;
/// `internet_connection_checker_plus` confirms the internet is actually
/// reachable (Wi-Fi without internet is common in auditoriums).
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity, InternetConnection? checker})
      : _connectivity = connectivity ?? Connectivity(),
        _checker = checker ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _checker;

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return false;
    return _checker.hasInternetAccess;
  }

  /// Emits only when the online/offline state actually changes.
  Stream<bool> get onStatusChange => _checker.onStatusChange
      .map((status) => status == InternetStatus.connected)
      .distinct();
}
