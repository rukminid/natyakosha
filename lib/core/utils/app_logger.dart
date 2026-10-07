import 'package:logger/logger.dart';

/// Thin wrapper over `logger` so logging can be switched off per env.
class AppLogger {
  AppLogger._();

  static Logger _logger = Logger(level: Level.off);

  static void init({required bool enabled}) {
    _logger = Logger(
      level: enabled ? Level.debug : Level.warning,
      printer: PrettyPrinter(methodCount: 0, errorMethodCount: 6, lineLength: 100),
    );
  }

  static void d(String message) => _logger.d(message);
  static void i(String message) => _logger.i(message);
  static void w(String message, [Object? error]) => _logger.w(message, error: error);
  static void e(String message, [Object? error, StackTrace? stack]) =>
      _logger.e(message, error: error, stackTrace: stack);
}
