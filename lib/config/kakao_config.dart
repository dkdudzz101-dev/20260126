import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'env_config.dart';

class KakaoConfig {
  static const String nativeAppKey = EnvConfig.kakaoNativeAppKey;
  static const String javaScriptAppKey = EnvConfig.kakaoJsAppKey;

  // 카카오 SDK 초기화
  static void initialize() {
    KakaoSdk.init(
      nativeAppKey: nativeAppKey,
      javaScriptAppKey: javaScriptAppKey,
    );
  }

  // 카카오맵 앱으로 자동차 길안내 연결
  static String getKakaoMapNavigationUrl({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    required String destName,
  }) {
    final encodedName = Uri.encodeComponent(destName);
    return 'kakaomap://route?sp=$startLat,$startLng&ep=$destLat,$destLng&ename=$encodedName&by=CAR';
  }

  // 카카오내비 앱으로 자동차 길안내
  static String getKakaoNaviUrl({
    required double destLat,
    required double destLng,
    required String destName,
  }) {
    final encodedName = Uri.encodeComponent(destName);
    return 'kakaonavi://navigate?ep=$destLat,$destLng&ename=$encodedName&rpOption=1';
  }

  // 카카오맵 웹 길안내 URL (좌표 직접 전달)
  static String getKakaoMapWebUrl({
    required double destLat,
    required double destLng,
    required String destName,
  }) {
    return 'https://map.kakao.com/link/map/$destName,$destLat,$destLng';
  }
}
