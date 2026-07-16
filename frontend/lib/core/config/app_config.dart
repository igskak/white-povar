class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'production',
  );

  /// Identifies the public catalog and runtime configuration for this build.
  /// Production-like builds must pass this explicitly; only development may use
  /// the pilot tenant while local bootstrap tooling is being completed.
  static const String tenantSlug = String.fromEnvironment(
    'TENANT_SLUG',
    defaultValue: environment == 'development' ? 'ohorodnik-oleksandr' : '',
  );

  // App Configuration
  static const String appName = 'White Povar';
  static const String appVersion = '1.0.0';
  static const String webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://white-povar-p79r.onrender.com',
  );
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: '',
  );
  static const String buildLabel = String.fromEnvironment(
    'BUILD_LABEL',
    defaultValue: 'v1.0.0',
  );
  static const bool googleOAuthEnabled = bool.fromEnvironment(
    'GOOGLE_OAUTH_ENABLED',
    defaultValue: false,
  );
  static const String authCallbackPath = '/auth/callback';
  static const String webAuthCallbackUrl = '$webAppUrl$authCallbackPath';
  static const String mobileAuthCallbackUrl =
      'io.supabase.cookingapp://login-callback';

  // Feature Flags
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  static const bool enableCrashlytics = bool.fromEnvironment(
    'ENABLE_CRASHLYTICS',
    defaultValue: false,
  );

  static void validateRequiredConfig() {
    final missing = <String>[];
    if (apiBaseUrl.isEmpty) missing.add('API_BASE_URL');
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (tenantSlug.isEmpty) missing.add('TENANT_SLUG');
    if (isProduction && supportEmail.isEmpty) missing.add('SUPPORT_EMAIL');

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required dart-define values: ${missing.join(', ')}. '
        'Set them via --dart-define for this build environment.',
      );
    }
  }

  // Helper methods
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  // API endpoints
  static String get authEndpoint => '$apiBaseUrl/api/v1/auth';
  static String get recipesEndpoint => '$apiBaseUrl/api/v1/recipes';
  static String get searchEndpoint => '$apiBaseUrl/api/v1/search';
  static String get configEndpoint => '$apiBaseUrl/api/v1/config';
  static String get uploadEndpoint => '$apiBaseUrl/api/v1/upload';
}
