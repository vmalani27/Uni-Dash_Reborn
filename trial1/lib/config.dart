class AppConfig {
  static late String backendUrl;
  
  /// Toggle this flag to switch between staging and production environments
  static const bool useStaging = true;

  /// Determines the appropriate backend URL based on environment and device context
  static String getBackendUrl(
    Map<String, String> env, {
    required bool isPhysicalDevice,
    required bool isWeb,
  }) {
    // Always use staging/production logic for all platforms
    String url = useStaging
        ? env['STAGING_BACKEND_URL'] ?? ''
        : env['PRODUCTION_BACKEND_URL'] ?? '';

    // Override for emulator/simulator (if detected)
    if (!isPhysicalDevice) {
      return env['EMULATOR_BACKEND_URL'] ?? url;
    }

    return url;
  }

  static void initialize(String url) {
    backendUrl = url;
  }
}
