import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 서비스 초기화
  static Future<void> initialize() async {
    // 알림 초기화
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    // 백그라운드 서비스 설정
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'jeju_oreum_location',
        initialNotificationTitle: '제주오름',
        initialNotificationContent: '오름 근처 자동 인증 활성화',
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
    return true;
  }

  // 서비스 시작 핸들러
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Supabase 초기화
    await Supabase.initialize(
      url: 'https://zsodcfgchbmmvpbwhuyu.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpzb2RjZmdjaGJtbXZwYndodXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc2NjU2MTQsImV4cCI6MjA4MzI0MTYxNH0.XkQHyzl0I-kJ3yZYniry-DXfKTDZ5H_b5qV-uNvmXe8',
    );

    final client = Supabase.instance.client;

    // 오름 정상 좌표 캐시
    List<Map<String, dynamic>> oreumSummits = [];
    Set<String> stampedOreums = {}; // 이미 인증된 오름 (중복 방지)

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

          // 200m 이내면 자동 스탬프
          if (distance <= 200) {
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
