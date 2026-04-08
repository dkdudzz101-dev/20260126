/// 환경변수 설정 (빌드 시 --dart-define-from-file=.env.json 으로 주입)
///
/// 개발: flutter run --dart-define-from-file=.env.json
/// 릴리즈: flutter build apk --dart-define-from-file=.env.json
class EnvConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://zsodcfgchbmmvpbwhuyu.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpzb2RjZmdjaGJtbXZwYndodXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc2NjU2MTQsImV4cCI6MjA4MzI0MTYxNH0.XkQHyzl0I-kJ3yZYniry-DXfKTDZ5H_b5qV-uNvmXe8');
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY',
      defaultValue: 'd4b730c14857dce93c9ba94e30f56260');
  static const kakaoJsAppKey = String.fromEnvironment('KAKAO_JS_APP_KEY',
      defaultValue: '1c8adf25a7ec61b19a19936513618f6a');
  static const openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY',
      defaultValue: 'f608cb7df83190a1358c804402a543eb');
  static const naverClientId = String.fromEnvironment('NAVER_CLIENT_ID',
      defaultValue: 'Ptn_X9wqz9PE6cXMTd1L');
  static const naverClientSecret = String.fromEnvironment('NAVER_CLIENT_SECRET',
      defaultValue: 'MyIXEaspaX');
}
