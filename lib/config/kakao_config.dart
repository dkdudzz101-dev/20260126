import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class KakaoConfig {
  // 카카오 개발자 콘솔에서 발급받은 앱 키
  static const String nativeAppKey = 'd4b730c14857dce93c9ba94e30f56260';
  static const String javaScriptAppKey = '1c8adf25a7ec61b19a19936513618f6a';

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
