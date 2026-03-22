import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../models/oreum_model.dart';
import '../../providers/oreum_provider.dart';
import '../../services/map_service.dart';
import '../../utils/ar_math.dart';

class ArCameraScreen extends StatefulWidget {
  const ArCameraScreen({super.key});

  @override
  State<ArCameraScreen> createState() => _ArCameraScreenState();
}

class _NearbyOreum {
  final OreumModel oreum;
  final double distance; // meters
  final double bearing; // degrees

  _NearbyOreum({
    required this.oreum,
    required this.distance,
    required this.bearing,
  });
}

class _ArCameraScreenState extends State<ArCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final MapService _mapService = MapService();

  double _compassHeading = 0;
  StreamSubscription? _accelSubscription;
  StreamSubscription? _magnetSubscription;

  // 센서 raw 값
  List<double> _accel = [0, 0, 0];
  List<double> _magnet = [0, 0, 0];
  bool _hasMagnet = false;

  // 스무딩
  double _smoothedHeading = 0;
  static const double _smoothingFactor = 0.15;

  double? _myLat;
  double? _myLng;
  List<_NearbyOreum> _nearbyOreums = [];
  Timer? _locationTimer;
  bool _isInitialized = false;
  String? _errorMessage;

  // 거리 필터
  static const List<int> _distanceOptions = [1000, 3000, 5000, 10000];
  static const List<String> _distanceLabels = ['1km', '3km', '5km', '10km'];
  int _selectedDistanceIndex = 1; // 기본 3km

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startSensors();
    // 위치 권한 요청 후 위치 업데이트 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await MapService.ensureLocationPermission(context);
      if (mounted) _startLocationUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _accelSubscription?.cancel();
    _magnetSubscription?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (!mounted) return;
          // iOS는 바로 설정으로 이동 후 돌아오면 권한 재확인
          if (Platform.isIOS) {
            await openAppSettings();
            if (!mounted) return;
            // 설정에서 돌아왔을 때 권한 다시 확인
            final recheckStatus = await Permission.camera.status;
            if (recheckStatus.isGranted) {
              // 권한 허용됐으면 카메라 재시작
              _initCamera();
            } else {
              // 여전히 거부면 안내 후 닫기
              setState(() => _errorMessage = '카메라 권한이 필요합니다.\n설정에서 카메라를 허용해주세요.');
            }
            return;
          }
          // Android는 안내 화면 표시
          setState(() => _errorMessage = '카메라 권한이 필요합니다.\nAR 기능을 사용하려면 설정에서 카메라 권한을 허용해주세요.');
          return;
        }
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = '카메라를 찾을 수 없습니다.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = '카메라 초기화 실패: $e');
    }
  }

  void _startSensors() {
    // 가속도계 (중력 포함)
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _accel = [event.x, event.y, event.z];
      _updateHeading();
    });

    // 자기장 센서
    _magnetSubscription = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _magnet = [event.x, event.y, event.z];
      _hasMagnet = true;
      _updateHeading();
    });
  }

  /// 가속도계 + 자기장으로 폰을 세운 상태의 heading 계산
  /// Android SensorManager.getRotationMatrix + getOrientation 과 동일하지만,
  /// remapCoordinateSystem(X, Z)를 적용하여 세로로 든 폰에 맞춤
  void _updateHeading() {
    if (!_hasMagnet || !mounted) return;

    final ax = _accel[0], ay = _accel[1], az = _accel[2];
    final mx = _magnet[0], my = _magnet[1], mz = _magnet[2];

    // 1) 정규화된 중력 벡터 (가속도계)
    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    if (normA < 0.1) return;
    final gx = ax / normA, gy = ay / normA, gz = az / normA;

    // 2) 동쪽 벡터 = 자기장 × 중력
    var ex = my * gz - mz * gy;
    var ey = mz * gx - mx * gz;
    var ez = mx * gy - my * gx;
    final normE = math.sqrt(ex * ex + ey * ey + ez * ez);
    if (normE < 0.1) return;
    ex /= normE;
    ey /= normE;
    ez /= normE;

    // 3) 북쪽 벡터 = 중력 × 동쪽
    // nz 성분만 필요 (세로 폰 heading 계산용)
    final nz = gx * ey - gy * ex;

    // 4) 폰을 세로로 들었을 때의 heading 계산
    // Android remapCoordinateSystem(AXIS_X, AXIS_Z) 후 getOrientation:
    // azimuth = atan2(East_z, North_z)
    // 세로로 든 폰에서 카메라가 바라보는 수평 방향의 방위각
    double heading = math.atan2(ez, nz) * 180 / math.pi;
    heading = (heading + 180 + 360) % 360;

    // 5) 스무딩 (급격한 변화 방지)
    double diff = heading - _smoothedHeading;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    _smoothedHeading = (_smoothedHeading + diff * _smoothingFactor + 360) % 360;

    setState(() {
      _compassHeading = _smoothedHeading;
    });
  }

  void _startLocationUpdates() {
    _updateLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateLocation(),
    );
  }

  Future<void> _updateLocation() async {
    final position = await _mapService.getCurrentPosition();
    if (position == null || !mounted) return;

    _myLat = position.latitude;
    _myLng = position.longitude;
    _updateNearbyOreums();
  }

  void _updateNearbyOreums() {
    if (_myLat == null || _myLng == null) return;

    final allOreums =
        Provider.of<OreumProvider>(context, listen: false).allOreums;

    final List<_NearbyOreum> nearby = [];

    for (final oreum in allOreums) {
      if (oreum.summitLat == null || oreum.summitLng == null) continue;

      final dist = _mapService.calculateDistance(
        _myLat!,
        _myLng!,
        oreum.summitLat!,
        oreum.summitLng!,
      );

      if (dist <= _distanceOptions[_selectedDistanceIndex]) {
        final bearing = calculateBearing(
          _myLat!,
          _myLng!,
          oreum.summitLat!,
          oreum.summitLng!,
        );
        nearby.add(_NearbyOreum(
          oreum: oreum,
          distance: dist,
          bearing: bearing,
        ));
      }
    }

    nearby.sort((a, b) => a.distance.compareTo(b.distance));

    if (mounted) {
      setState(() {
        _nearbyOreums = nearby.take(15).toList();
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _compassDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading < 67.5) return 'NE';
    if (heading < 112.5) return 'E';
    if (heading < 157.5) return 'SE';
    if (heading < 202.5) return 'S';
    if (heading < 247.5) return 'SW';
    if (heading < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _errorMessage != null
          ? _buildError()
          : !_isInitialized
              ? _buildLoading()
              : _buildArView(),
    );
  }

  Widget _buildError() {
    final isPermissionError = _errorMessage?.contains('권한') ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionError ? Icons.camera_alt_outlined : Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isPermissionError)
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('설정으로 이동',
                    style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('돌아가기',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('카메라 준비 중...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildArView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 카메라 프리뷰
        CameraPreview(_cameraController!),

        // 오름 라벨들
        ..._buildOreumLabels(),

        // 좌상단 뒤로가기
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
        ),

        // 우상단 나침반
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -_compassHeading * math.pi / 180,
                  child: const Icon(Icons.navigation,
                      color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_compassHeading.round()}° ${_compassDirection(_compassHeading)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 상단 베타 안내 배너
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'BETA  GPS 기반 주변 오름 방향·거리 참고용',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 하단 거리 필터
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_nearbyOreums.length}개 오름',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_distanceOptions.length, (i) {
                  final selected = i == _selectedDistanceIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDistanceIndex = i);
                      _updateNearbyOreums();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _distanceLabels[i],
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOreumLabels() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final List<Widget> labels = [];
    const cameraFov = 75.0;
    const labelHeight = 52.0; // 라벨 대략 높이
    const labelWidth = 120.0;

    // 이미 배치된 라벨들의 영역 (겹침 방지용)
    final List<Rect> placed = [];

    final maxDist = _distanceOptions[_selectedDistanceIndex].toDouble();

    for (int i = 0; i < _nearbyOreums.length; i++) {
      final nearby = _nearbyOreums[i];
      final xRatio = oreumScreenX(
        compassHeading: _compassHeading,
        oreumBearing: nearby.bearing,
        fov: cameraFov,
      );

      if (xRatio == null) continue;

      final x = (screenWidth / 2 + xRatio * (screenWidth / 2) - labelWidth / 2)
          .clamp(4.0, screenWidth - labelWidth - 4);

      // 기본 Y: 가까우면 아래, 멀면 위
      final yBase = screenHeight * 0.25 +
          (nearby.distance / maxDist) * screenHeight * 0.30;

      // 겹침 방지: 위아래로 밀어냄
      double y = yBase;
      final candidate = Rect.fromLTWH(x, y, labelWidth, labelHeight);
      int attempts = 0;
      while (_overlaps(candidate.translate(0, y - yBase), placed) && attempts < 8) {
        attempts++;
        // 번갈아 위/아래로
        y = yBase + (attempts.isOdd ? 1 : -1) * ((attempts + 1) ~/ 2) * (labelHeight + 6);
      }
      // 화면 범위 내로
      y = y.clamp(
        MediaQuery.of(context).padding.top + 60,
        screenHeight - 120,
      );

      placed.add(Rect.fromLTWH(x, y, labelWidth, labelHeight));

      labels.add(
        Positioned(
          left: x,
          top: y,
          child: _buildOreumLabel(nearby),
        ),
      );
    }

    return labels;
  }

  bool _overlaps(Rect rect, List<Rect> others) {
    for (final other in others) {
      if (rect.overlaps(other)) return true;
    }
    return false;
  }

  Widget _buildOreumLabel(_NearbyOreum nearby) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nearby.oreum.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatDistance(nearby.distance)}'
            '${nearby.oreum.elevation != null ? ' · ${nearby.oreum.elevation}m' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
