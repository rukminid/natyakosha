import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// flutter run -t lib/main_staging.dart
Future<void> main() => bootstrap(Flavor.staging);
