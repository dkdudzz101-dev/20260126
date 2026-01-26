import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/oreum_model.dart';
import '../services/stamp_service.dart';

class StampModel {
  final String id;
  final String oreumId;
  final String oreumName;
  final DateTime stampedAt;
  final double lat;
  final double lng;
  final String? stampUrl;

  // 확장 필드
  final double? distanceWalked;
  final int? timeTaken;
  final int? steps;
  final double? avgSpeed;
  final int? calories;
  final double? elevationGain;
  final double? elevationLoss;
  final double? maxAltitude;
  final double? minAltitude;

  static const String _storageBaseUrl = 'https://zsodcfgchbmmvpbwhuyu.supabase.co/storage/v1/object/public/oreum-data/';

  StampModel({
    required this.id,
    required this.oreumId,
    required this.oreumName,
    required this.stampedAt,
    required this.lat,
    required this.lng,
    this.stampUrl,
    this.distanceWalked,
    this.timeTaken,
    this.steps,
    this.avgSpeed,
    this.calories,
    this.elevationGain,
    this.elevationLoss,
    this.maxAltitude,
    this.minAltitude,
  });

  // 스탬프 이미지 URL (상대경로 → 전체 URL 변환)
  String? get imageUrl {
    if (stampUrl == null) return null;
    if (stampUrl!.startsWith('http')) return stampUrl;
    return '$_storageBaseUrl$stampUrl';
  }

  factory StampModel.fromJson(Map<String, dynamic> json) {
    final oreum = json['oreums'] as Map<String, dynamic>?;
    return StampModel(
      id: json['id']?.toString() ?? '',
      oreumId: json['oreum_id'] ?? '',
      oreumName: oreum?['name'] ?? json['oreum_id'] ?? '오름',
      stampedAt: DateTime.tryParse(json['completed_at'] ?? '') ?? DateTime.now(),
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      stampUrl: oreum?['stamp_url'],
      distanceWalked: json['distance_walked']?.toDouble(),
      timeTaken: json['time_taken'],
      steps: json['steps'],
      avgSpeed: json['avg_speed']?.toDouble(),
      calories: json['calories'],
      elevationGain: json['elevation_gain']?.toDouble(),
      elevationLoss: json['elevation_loss']?.toDouble(),
      maxAltitude: json['max_altitude']?.toDouble(),
      minAltitude: json['min_altitude']?.toDouble(),
    );
  }
}

class StampProvider extends ChangeNotifier {
  final StampService _stampService = StampService();

  List<StampModel> _stamps = [];
  Set<String> _stampedOreumIds = {};
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  double _totalDistance = 0.0;
  int _totalSteps = 0;

  List<StampModel> get stamps => _stamps;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get stampCount => _stamps.length;
  double get totalDistance => _totalDistance;
  int get totalSteps => _totalSteps;

  // 스탬프 목록 로드 (Supabase에서)
  Future<void> loadStamps() async {
    _isLoading = true;
    notifyListeners();

    try {
      final stampData = await _stampService.getUserStamps();
      _stamps.clear();
      _stampedOreumIds.clear();

      for (final data in stampData) {
        final stamp = StampModel.fromJson(data);
        _stamps.add(stamp);
        _stampedOreumIds.add(stamp.oreumId);
      }
      // 가나다순 정렬
      _stamps.sort((a, b) => a.oreumName.compareTo(b.oreumName));

      // 총 이동거리/걸음수 로드
      _totalDistance = await _stampService.getTotalDistance();
      _totalSteps = await _stampService.getTotalSteps();
    } catch (e) {
      debugPrint('스탬프 로드 에러: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // GPS 위치 확인 권한 요청
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = '위치 서비스가 비활성화되어 있습니다';
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = '위치 권한이 거부되었습니다';
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _error = '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      _error = '위치를 가져올 수 없습니다: $e';
      return null;
    }
  }

  // 스탬프 인증 (정상 200m 이내 확인)
  Future<StampResult> verifyAndStamp(OreumModel oreum) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 이미 스탬프가 있는지 확인
      if (_stamps.any((s) => s.oreumId == oreum.id)) {
        return StampResult(
          success: false,
          message: '이미 이 오름의 스탬프를 획득했습니다',
        );
      }

      // 현재 위치 가져오기
      final position = await getCurrentPosition();
      if (position == null) {
        return StampResult(
          success: false,
          message: _error ?? '위치를 확인할 수 없습니다',
        );
      }

      // 정상 좌표 확인
      if (oreum.summitLat == null || oreum.summitLng == null) {
        // 정상 좌표가 없으면 입구 좌표로 확인
        if (oreum.startLat == null || oreum.startLng == null) {
          return StampResult(
            success: false,
            message: '오름 위치 정보가 없습니다',
          );
        }
      }

      // 거리 계산 (정상 우선, 없으면 입구)
      final targetLat = oreum.summitLat ?? oreum.startLat!;
      final targetLng = oreum.summitLng ?? oreum.startLng!;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );

      // 200m 이내인지 확인
      if (distance > 200) {
        return StampResult(
          success: false,
          message: '정상에서 ${distance.toInt()}m 떨어져 있습니다.\n200m 이내에서 인증해주세요.',
          distance: distance,
        );
      }

      // Supabase에 스탬프 저장 시도
      try {
        await _stampService.recordStamp(
          oreumId: oreum.id,
          distanceWalked: oreum.distance?.toDouble(),
          timeTaken: oreum.timeUp,
        );
      } catch (e) {
        debugPrint('Supabase 스탬프 저장 에러 (로컬에만 저장): $e');
      }

      // 스탬프 발급
      final stamp = StampModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        oreumId: oreum.id,
        oreumName: oreum.name,
        stampedAt: DateTime.now(),
        lat: position.latitude,
        lng: position.longitude,
        stampUrl: oreum.stampUrl,
      );

      _stamps.add(stamp);
      _stampedOreumIds.add(oreum.id);
      notifyListeners();

      return StampResult(
        success: true,
        message: '${oreum.name} 스탬프를 획득했습니다!',
        stamp: stamp,
      );
    } catch (e) {
      return StampResult(
        success: false,
        message: '스탬프 인증 중 오류가 발생했습니다: $e',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 오름의 스탬프 여부 확인
  bool hasStamp(String oreumId) {
    return _stampedOreumIds.contains(oreumId) || _stamps.any((s) => s.oreumId == oreumId);
  }

  // 스탬프 획득 날짜 가져오기
  DateTime? getStampDate(String oreumId) {
    final stamp = _stamps.where((s) => s.oreumId == oreumId).firstOrNull;
    return stamp?.stampedAt;
  }
}

class StampResult {
  final bool success;
  final String message;
  final double? distance;
  final StampModel? stamp;

  StampResult({
    required this.success,
    required this.message,
    this.distance,
    this.stamp,
  });
}
