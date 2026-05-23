abstract final class AppRoutes {
  static const home = '/';
  static const unsupported = '/unsupported';
  static const appDetail = '/app/:packageName';
  static const dependencyDetail = '/dependency/:packageName';

  static String appDetailPath(String packageName) => '/app/$packageName';
  static String dependencyDetailPath(String packageName) =>
      '/dependency/$packageName';
}
