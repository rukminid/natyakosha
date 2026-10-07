/// Build flavors. Each has its own entry point (`lib/main_<flavor>.dart`)
/// and its own env file (`.env.<flavor>`).
enum Flavor {
  dev,
  staging,
  prod;

  String get envFile => '.env.$name';

  bool get isProd => this == Flavor.prod;
}
