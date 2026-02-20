class AppConfig {
  static late String backendUrl;

  static void initialize(String url) {
    backendUrl = url;
  }
}
