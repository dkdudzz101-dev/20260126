import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/kakao_config.dart';
import '../screens/permission/location_permission_screen.dart';

class MapService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  /// 중앙화된 위치 권한 확인 + 전체화면 공개 + 요청 플로우.
  ///
  /// - 이미 권한 있으면 → true
  /// - deniedForever이면 → false
  /// - 첫 요청이면 → LocationPermissionScreen(전체화면) 표시 후 OS 권한 요청
  /// - 이미 설명 본 적 있으면 → OS 권한 다이얼로그 직접 호출
  static Future<bool> ensureLocationPermission(BuildContext context) async {
    // 위치 서비스 활성화 확인
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // 현재 권한 상태 확인
    var status = await Permission.locationWhenInUse.status;

    if (status.isGranted) return true;

    // 영구 거부: 설정으로 이동 안내
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('위치 권한 필요'),
          content: const Text('위치 권한이 거부되어 있습니다.\n설정에서 위치 권한을 허용해주세요.\n\n설정 > 제주오름 > 위치 > 앱을 사용하는 동안'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        ),
      );
      return false;
    }

    // 전체화면 공개를 보여준 적이 있는지 확인
    final disclosureShown = await LocationPermissionScreen.wasDisclosureShown();

    if (!disclosureShown) {
      // 첫 요청: 전체화면 설명 화면으로 이동 (내부에서 권한 요청까지 처리)
      if (!context.mounted) return false;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const LocationPermissionScreen(),
        ),
      );
      return result == true;
    }

    // 이미 설명을 본 적 있으면 OS 권한 다이얼로그 직접 호출
    final result = await Permission.locationWhenInUse.request();
    // 요청 후에도 거부된 경우 설정으로 이동 안내
    if (!result.isGranted) {
      final newStatus = await Permission.locationWhenInUse.status;
      if (newStatus.isPermanentlyDenied && context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('위치 권한 필요'),
            content: const Text('위치 권한이 거부되어 있습니다.\n설정에서 위치 권한을 허용해주세요.\n\n설정 > 제주오름 > 위치 > 앱을 사용하는 동안'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
      }
    }
    return result.isGranted;
  }

  // 위치 권한 확인 (요청 X — 권한 공개/요청은 ensureLocationPermission에서 처리)
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  // 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await checkAndRequestPermission()) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        return Geolocator.getLastKnownPosition().then((pos) => pos!);
      });
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // 위치 추적 시작 (등산 모드)
  void startTracking({
    int distanceFilter = 5,
    Function(Position)? onPositionUpdate,
  }) {
    _positionSubscription?.cancel();

    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 3),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _positionController.add(position);
      onPositionUpdate?.call(position);
    });
  }

  // 위치 추적 중지
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // 두 좌표 사이 거리 계산 (미터)
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // 정상 도착 확인 (100m 이내)
  bool isAtSummit(
    Position currentPosition,
    double summitLat,
    double summitLng, {
    double threshold = 100,
  }) {
    final distance = calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      summitLat,
      summitLng,
    );
    return distance <= threshold;
  }

  // 등산로 이탈 확인
  bool isOffTrail(
    Position currentPosition,
    List<List<double>> trailCoordinates, {
    double threshold = 50,
  }) {
    for (final coord in trailCoordinates) {
      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        coord[1],
        coord[0],
      );
      if (distance <= threshold) {
        return false;
      }
    }
    return true;
  }

  // 카카오 자동차 길안내 시작
  Future<bool> openKakaoMapNavigation({
    required double destLat,
    required double destLng,
    required String destName,
  }) async {
    // 현재 위치 가져오기
    final position = await getCurrentPosition();
    final startLat = position?.latitude ?? 33.4996;
    final startLng = position?.longitude ?? 126.5312;

    // 1. 카카오맵 앱으로 자동차 길안내 (출발지 포함)
    final kakaoMapUri = Uri.parse(KakaoConfig.getKakaoMapNavigationUrl(
      startLat: startLat,
      startLng: startLng,
      destLat: destLat,
      destLng: destLng,
      destName: destName,
    ));

    if (await canLaunchUrl(kakaoMapUri)) {
      return await launchUrl(kakaoMapUri);
    }

    // 2. 앱이 없으면 웹으로
    final webUri = Uri.parse(KakaoConfig.getKakaoMapWebUrl(
      destLat: destLat,
      destLng: destLng,
      destName: destName,
    ));

    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  // 총 이동 거리 계산
  double calculateTotalDistance(List<Position> positions) {
    if (positions.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < positions.length; i++) {
      total += calculateDistance(
        positions[i - 1].latitude,
        positions[i - 1].longitude,
        positions[i].latitude,
        positions[i].longitude,
      );
    }
    return total;
  }

  // GeoJSON 좌표를 LatLng 리스트로 변환
  List<List<double>> parseGeoJsonCoordinates(Map<String, dynamic> geojson) {
    final List<List<double>> coordinates = [];

    try {
      final features = geojson['features'] as List?;
      if (features != null && features.isNotEmpty) {
        for (final feature in features) {
          final geometry = feature['geometry'];
          if (geometry != null) {
            final type = geometry['type'];
            final coords = geometry['coordinates'];

            if (type == 'LineString') {
              for (final coord in coords) {
                coordinates.add([coord[0].toDouble(), coord[1].toDouble()]);
              }
            } else if (type == 'MultiLineString') {
              for (final line in coords) {
                for (final coord in line) {
                  coordinates.add([coord[0].toDouble(), coord[1].toDouble()]);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing GeoJSON: $e');
    }

    return coordinates;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _positionController.close();
  }
}
