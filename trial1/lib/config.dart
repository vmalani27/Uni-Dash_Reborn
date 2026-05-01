class AppConfig {
  static late String backendUrl;
  static const bool useStaging = true;

  static String getBackendUrl(Map<String, String> env) {
    return useStaging
        ? env['STAGING_BACKEND_URL'] ?? ''
        : env['PRODUCTION_BACKEND_URL'] ?? '';
  }

  static void initialize(String url) {
    backendUrl = url;
  }
}

