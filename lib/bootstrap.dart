import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/flavor.dart';
import 'core/di/locator.dart';
import 'core/network/connectivity_service.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';
import 'redux/actions/app_actions.dart';
import 'redux/store.dart';

/// Shared startup for every flavor:
/// env → Firebase → local storage + DI → Redux store → connectivity → runApp.
Future<void> bootstrap(Flavor flavor) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    await Env.load(flavor);
    AppLogger.init(enabled: Env.enableLogs);

    final firebaseReady = await _initFirebase();

    await setupLocator();

    final store = createStore(firebaseReady: firebaseReady);

    FlutterError.onError = (details) {
      AppLogger.e('Flutter error', details.exception, details.stack);
    };

    runApp(NatyakoshaApp(store: store));

    // Push online/offline changes into Redux so any screen can react.
    // Done after runApp: the first check can take a few seconds on
    // Wi-Fi without internet, and must not hold up the first frame.
    final connectivity = locator<ConnectivityService>();
    connectivity.onStatusChange.listen(
      (online) => store.dispatch(SetConnectivityAction(isOnline: online)),
    );
    store.dispatch(SetConnectivityAction(isOnline: await connectivity.isOnline()));
  }, (error, stack) => AppLogger.e('Uncaught error', error, stack));
}

Future<bool> _initFirebase() async {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey == 'REPLACE_ME') {
      AppLogger.w('Firebase placeholder config found. Run `flutterfire configure`.');
      return false;
    }
    await Firebase.initializeApp(options: options);
    // Firestore keeps a local cache and queues writes while offline,
    // so attendance marked in a hall with no signal syncs later on its own.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    return true;
  } catch (e, st) {
    AppLogger.e(
      'Firebase not initialised. Run `flutterfire configure` to set it up.',
      e,
      st,
    );
    return false;
  }
}
