import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/kakao_config.dart';

class MapService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  // 위치 권한 확인 및 요청
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
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
        desiredAccuracy: LocationAccuracy.high,
      );
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
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "등산 경로를 기록하고 있습니다",
          notificationTitle: "제주오름",
          enableWakeLock: true,
        ),
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

  // 카카오맵으로 길안내 시작
  Future<bool> openKakaoMapNavigation({
    required double destLat,
    required double destLng,
    required String destName,
  }) async {
    // 먼저 카카오맵 앱으로 시도
    final kakaoMapUri = Uri.parse(KakaoConfig.getKakaoMapNavigationUrl(
      destLat: destLat,
      destLng: destLng,
      destName: destName,
    ));

    if (await canLaunchUrl(kakaoMapUri)) {
      return await launchUrl(kakaoMapUri);
    }

    // 앱이 없으면 웹으로
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
