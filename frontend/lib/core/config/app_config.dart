class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qnlfvpqmkmbvzmzqgjpo.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFubGZ2cHFta21idnptenFnanBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ4NDQ2NDAsImV4cCI6MjA3MDQyMDY0MH0.ll2KBzdgAKUErgGKhgxKsDV3WWGDkfb3-hHCjPKtzxg',
  );
  
  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );
  
  // App Configuration
  static const String appName = 'White-Label Cooking App';
  static const String appVersion = '1.0.0';
  
  // Feature Flags
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );
  
  static const bool enableCrashlytics = bool.fromEnvironment(
    'ENABLE_CRASHLYTICS',
    defaultValue: false,
  );
  
  // Helper methods
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';
  
  // API endpoints
  static String get authEndpoint => '$apiBaseUrl/api/auth';
  static String get recipesEndpoint => '$apiBaseUrl/api/recipes';
  static String get configEndpoint => '$apiBaseUrl/api/config';
  static String get uploadEndpoint => '$apiBaseUrl/api/upload';
}
