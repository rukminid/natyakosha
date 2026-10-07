import 'bootstrap.dart';
import 'core/config/flavor.dart';

/// Default entry point (`flutter run` with no -t) uses the dev flavor.
Future<void> main() => bootstrap(Flavor.dev);
