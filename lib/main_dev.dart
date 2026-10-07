import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// flutter run -t lib/main_dev.dart
Future<void> main() => bootstrap(Flavor.dev);
