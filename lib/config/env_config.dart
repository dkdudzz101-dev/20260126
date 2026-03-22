/// 환경변수 설정 (빌드 시 --dart-define-from-file=.env.json 으로 주입)
///
/// 개발: flutter run --dart-define-from-file=.env.json
/// 릴리즈: flutter build apk --dart-define-from-file=.env.json
class EnvConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  static const kakaoJsAppKey = String.fromEnvironment('KAKAO_JS_APP_KEY');
  static const openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  static const naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');
  static const naverClientSecret = String.fromEnvironment('NAVER_CLIENT_SECRET');
}
