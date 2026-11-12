/// Konfigurasi aplikasi. Kredensial Supabase dari --dart-define, jangan di-hardcode.
class AppConfig {
  static const appName = 'Satu Pintu';
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const logoAsset = 'assets/brand/app_logo.png';
  static const defaultBasePortions = 25;
  static const photoMaxSize = 480.0;
  static const minPasswordLength = 6;

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
