import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'config/supabase_config.dart';
import 'config/kakao_config.dart';
import 'theme/app_theme.dart';
import 'screens/main_tab_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/oreum_provider.dart';
import 'providers/stamp_provider.dart';
import 'providers/community_provider.dart';
import 'providers/badge_provider.dart';
import 'services/pedometer_service.dart';
import 'services/background_location_service.dart';

void main() async {
  // 글로벌 에러 핸들러 - Supabase가 카카오 딥링크를 처리하려고 할 때 발생하는 에러를 무시
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Supabase 초기화
      await SupabaseConfig.initialize();

      // 카카오 SDK 초기화
      KakaoConfig.initialize();

      // 카카오맵 초기화
      AuthRepository.initialize(appKey: KakaoConfig.javaScriptAppKey);
    } catch (e) {
      debugPrint('SDK 초기화 에러: $e');
    }

    // 걸음수 서비스 초기화
    final pedometerService = PedometerService();
    try {
      await pedometerService.initialize();
    } catch (e) {
      debugPrint('걸음수 서비스 초기화 에러: $e');
    }

    // 백그라운드 위치 서비스 초기화
    try {
      await BackgroundLocationService.initialize();
    } catch (e) {
      debugPrint('백그라운드 위치 서비스 초기화 에러: $e');
    }

    runApp(MyApp(pedometerService: pedometerService));
  }, (error, stackTrace) {
    // Supabase가 카카오 딥링크를 처리하려고 할 때 발생하는 에러 무시
    final errorString = error.toString();
    if (errorString.contains('Code verifier') ||
        errorString.contains('AuthException') ||
        errorString.contains('pkce')) {
      debugPrint('Supabase OAuth 에러 무시 (카카오 딥링크): $error');
      return;
    }
    // 다른 에러는 로그 출력
    debugPrint('글로벌 에러: $error');
    debugPrint('스택 트레이스: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  final PedometerService pedometerService;

  const MyApp({super.key, required this.pedometerService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OreumProvider()),
        ChangeNotifierProvider(create: (_) => StampProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => BadgeProvider()),
        ChangeNotifierProvider.value(value: pedometerService),
      ],
      child: MaterialApp(
        title: '제주오름',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainTabScreen(),
      ),
    );
  }
}
