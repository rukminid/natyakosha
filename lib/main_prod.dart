import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// flutter run -t lib/main_prod.dart --release
Future<void> main() => bootstrap(Flavor.prod);
