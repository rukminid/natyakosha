import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:redux/redux.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'redux/state/app_state.dart';
import 'shared/widgets/offline_banner.dart';

class NatyakoshaApp extends StatefulWidget {
  const NatyakoshaApp({super.key, required this.store});

  final Store<AppState> store;

  @override
  State<NatyakoshaApp> createState() => _NatyakoshaAppState();
}

class _NatyakoshaAppState extends State<NatyakoshaApp> {
  late final GoRouter _router = createRouter(widget.store);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // StoreProvider is react-redux's <Provider store={store}>.
    return StoreProvider<AppState>(
      store: widget.store,
      child: MaterialApp.router(
        title: Env.appName,
        debugShowCheckedModeBanner: !Env.flavor.isProd,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        routerConfig: _router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FormBuilderLocalizations.delegate,
        ],
        // Add Locale('te'), Locale('ta'), Locale('hi') once translations exist.
        supportedLocales: const [Locale('en')],
        // Every screen gets the offline banner on top.
        builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
