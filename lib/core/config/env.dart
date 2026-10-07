import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'flavor.dart';

/// Typed access to values from the active `.env.<flavor>` file.
///
/// Call [Env.load] once in bootstrap before anything reads a value.
class Env {
  Env._();

  static late Flavor flavor;

  static Future<void> load(Flavor f) async {
    flavor = f;
    await dotenv.load(fileName: f.envFile);
  }

  static String get appName => _string('APP_NAME', fallback: 'Natyakosha');
  static String get apiBaseUrl => _string('API_BASE_URL');
  static int get apiTimeoutMs => _int('API_TIMEOUT_MS', fallback: 20000);
  static bool get enableLogs => _bool('ENABLE_LOGS', fallback: !flavor.isProd);
  static int get imageMaxDimension => _int('IMAGE_MAX_DIMENSION', fallback: 1600);
  static int get imageQuality => _int('IMAGE_QUALITY', fallback: 70);

  static String _string(String key, {String fallback = ''}) =>
      dotenv.maybeGet(key) ?? fallback;

  static int _int(String key, {required int fallback}) =>
      int.tryParse(dotenv.maybeGet(key) ?? '') ?? fallback;

  static bool _bool(String key, {required bool fallback}) {
    final raw = dotenv.maybeGet(key)?.toLowerCase();
    if (raw == null) return fallback;
    return raw == 'true' || raw == '1';
  }
}
