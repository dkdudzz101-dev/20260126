import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 서비스 초기화
  static Future<void> initialize() async {
    // 알림 초기화
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);

    // 백그라운드 서비스 설정
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'jeju_oreum_location',
        initialNotificationTitle: '제주오름',
        initialNotificationContent: '등산 중 - 위치 및 걸음수 추적 활성화',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // iOS 백그라운드 핸들러
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // iOS 백그라운드에서도 위치 체크 수행
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint('iOS 백그라운드 위치: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('iOS 백그라운드 위치 체크 실패: $e');
    }

    return true;
  }

  // 서비스 시작 핸들러
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Supabase 초기화
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    final client = Supabase.instance.client;

    // === 걸음수 추적 ===
    int bgBaseSteps = 0;
    bool bgBaseStepsSet = false;

    // SharedPreferences에서 기존 걸음수 데이터 로드
    final prefs = await SharedPreferences.getInstance();
    final savedBgSteps = prefs.getInt('bg_pedometer_steps') ?? 0;

    // 걸음수 스트림 리스닝
    StreamSubscription<StepCount>? stepSubscription;
    try {
      stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          if (!bgBaseStepsSet) {
            // 첫 이벤트: 기준점 설정
            bgBaseSteps = event.steps - savedBgSteps;
            bgBaseStepsSet = true;
          }

          final currentSteps = event.steps - bgBaseSteps;
          if (currentSteps < 0) return;

          // SharedPreferences에 저장 (포그라운드 PedometerService와 동기화)
          final p = await SharedPreferences.getInstance();
          await p.setInt('bg_pedometer_steps', currentSteps);

          // PedometerService의 today_steps도 업데이트
          final existingTodaySteps = p.getInt('pedometer_today_steps') ?? 0;
          if (currentSteps > existingTodaySteps) {
            await p.setInt('pedometer_today_steps', currentSteps);
          }

          debugPrint('백그라운드 걸음수: $currentSteps');
        },
        onError: (error) {
          debugPrint('백그라운드 걸음수 에러: $error');
        },
      );
    } catch (e) {
      debugPrint('백그라운드 걸음수 스트림 시작 실패: $e');
    }

    // === 위치 추적 (자동 스탬프) ===
    List<Map<String, dynamic>> oreumSummits = [];
    Set<String> stampedOreums = {};

    // 오름 데이터 로드
    Future<void> loadOreums() async {
      try {
        final response = await client
            .from('oreums')
            .select('id, name, summit_lat, summit_lng')
            .not('summit_lat', 'is', null)
            .not('summit_lng', 'is', null);
        oreumSummits = List<Map<String, dynamic>>.from(response);
      } catch (e) {
        debugPrint('오름 데이터 로드 실패: $e');
      }
    }

    // 이미 인증된 오름 로드
    Future<void> loadUserStamps() async {
      try {
        final userId = client.auth.currentUser?.id;
        if (userId == null) return;

        final response = await client
            .from('stamps')
            .select('oreum_id')
            .eq('user_id', userId);

        for (final stamp in response) {
          stampedOreums.add(stamp['oreum_id'].toString());
        }
      } catch (e) {
        debugPrint('스탬프 로드 실패: $e');
      }
    }

    // 스탬프 기록
    Future<void> recordStamp(String oreumId, String oreumName) async {
      try {
        final userId = client.auth.currentUser?.id;
        if (userId == null) return;

        await client.from('stamps').upsert({
          'user_id': userId,
          'oreum_id': oreumId,
          'completed_at': DateTime.now().toIso8601String(),
        });

        stampedOreums.add(oreumId);

        // 알림 표시
        await _notifications.show(
          int.parse(oreumId),
          '스탬프 획득!',
          '$oreumName 정상 근처를 지나 자동 인증되었습니다.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'stamp_channel',
              '스탬프 알림',
              channelDescription: '오름 스탬프 자동 인증 알림',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      } catch (e) {
        debugPrint('스탬프 기록 실패: $e');
      }
    }

    // 거리 계산 (미터)
    double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
      return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    }

    // 위치 체크
    Future<void> checkLocation() async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        for (final oreum in oreumSummits) {
          final oreumId = oreum['id'].toString();

          // 이미 인증된 오름은 스킵
          if (stampedOreums.contains(oreumId)) continue;

          final summitLat = oreum['summit_lat'] as double;
          final summitLng = oreum['summit_lng'] as double;
          final name = oreum['name'] as String;

          final distance = calculateDistance(
            position.latitude,
            position.longitude,
            summitLat,
            summitLng,
          );

          // 100m 이내면 자동 스탬프
          if (distance <= 100) {
            await recordStamp(oreumId, name);
          }
        }
      } catch (e) {
        debugPrint('위치 체크 실패: $e');
      }
    }

    // 초기 데이터 로드
    await loadOreums();
    await loadUserStamps();

    // 30초마다 위치 체크
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      await checkLocation();
    });

    // 서비스 종료 핸들러
    service.on('stopService').listen((event) {
      stepSubscription?.cancel();
      service.stopSelf();
    });
  }

  // 서비스 시작
  static Future<void> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
  }

  // 서비스 중지
  static Future<void> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }

  // 서비스 상태 확인
  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}
