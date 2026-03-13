import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../models/oreum_model.dart';
import '../../services/map_service.dart';
import '../../services/stamp_service.dart';
import '../../services/pedometer_service.dart';
import '../../services/trail_service.dart';
import '../../services/hiking_route_service.dart';
import '../../services/share_service.dart';
import '../../services/background_location_service.dart';
import '../../utils/calorie_calculator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../utils/login_guard.dart';
import '../../widgets/hiking_share_card.dart';
import '../oreum/oreum_error_report_screen.dart';
import '../oreum/oreum_detail_screen.dart';
import '../permission/background_location_permission_screen.dart';

class HikingScreen extends StatefulWidget {
  final OreumModel oreum;
  final bool autoStart;

  const HikingScreen({super.key, required this.oreum, this.autoStart = false});

  @override
  State<HikingScreen> createState() => _HikingScreenState();
}

class _HikingScreenState extends State<HikingScreen> with WidgetsBindingObserver {
  final MapService _mapService = MapService();
  final StampService _stampService = StampService();
  final TrailService _trailService = TrailService();
  final HikingRouteService _hikingRouteService = HikingRouteService();

  KakaoMapController? _mapController;

  // 현재 위치 커스텀 오버레이
  Set<CustomOverlay> _userLocationOverlay = {};

  // 정상 인증 범위 원 (100m 반경)
  Set<Circle> _summitRangeCircle = {};
  Set<CustomOverlay> _summitRangeLabel = {};

  // 등반 상태
  bool _isHiking = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _isStarting = false; // 등산 시작 처리 중 (중복 방지)

  // 추적 데이터
  Position? _currentPosition;
  List<Position> _trackPositions = [];
  double _totalDistance = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;

  // 걸음수 추적
  int _startSteps = 0;
  int _hikingSteps = 0;

  // 고도 추적
  double _maxAltitude = 0;
  double _minAltitude = double.infinity;
  double _elevationGain = 0;
  double _elevationLoss = 0;
  double _lastAltitude = 0;
  double _currentAltitude = 0;

  // 칼로리
  int _calculatedCalories = 0;

  // 정상 도착 추적
  double _distanceToSummit = 0;
  bool _reachedSummit = false;
  bool _summitDialogShown = false;

  // 하산 모드
  bool _isDescending = false;
  bool _isFacilityPanelOpen = true;
  bool _descentCompleted = false;
  double _descentDistance = 0;
  int _descentSeconds = 0;
  int _descentSteps = 0;
  int _descentStartSteps = 0;
  double _descentElevationGain = 0;
  double _descentElevationLoss = 0;
  int _descentCalories = 0;
  bool _descentDialogShown = false;
  // 등산 데이터 스냅샷 (하산 시작 시 저장)
  double _ascentDistance = 0;
  int _ascentSeconds = 0;
  int _ascentSteps = 0;

  // 마커
  Set<Marker> _markers = {};
  Set<Marker> _facilityMarkers = {}; // 시설물 마커
  Set<Polyline> _trackPolyline = {};
  Set<Polyline> _trailPolylines = {}; // 등산로 표시용

  // 시설물
  List<FacilityPoint> _currentFacilities = [];
  FacilityPoint? _selectedFacility;

  // 사진 촬영
  final ImagePicker _imagePicker = ImagePicker();
  List<File> _hikingPhotos = [];

  // 지도 캡처용 키
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
    _loadTrail(); // 등산로 로드
    _restoreHikingState(); // 저장된 등산 상태 복원
    if (widget.autoStart) {
      _isStarting = true; // 첫 프레임부터 "등반 시작" 버튼 숨김
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startHiking();
      });
    }
  }

  // 시설물 마커 이미지 (SVG data URL)
  String _getFacilityMarkerImage(String type, bool isSelected) {
    // 선택 시 빨간색, 비선택 시 녹색
    final color = isSelected ? '%23E53935' : '%232D9B4E'; // URL encoded #
    final strokeColor = isSelected ? '%23FFEB3B' : 'white'; // 선택 시 노란 테두리
    final strokeWidth = isSelected ? 3 : 2;
    final size = isSelected ? 36 : 28; // 선택 시 더 크게

    // 시설물 타입별 아이콘 심볼
    String symbol;
    switch (type) {
      case '시종점':
        symbol = 'S';
      case '정상':
        symbol = '▲';
      case '화장실':
        symbol = 'WC';
      case '쉼터':
        symbol = 'R';
      case '주차장':
        symbol = 'P';
      case '매점':
        symbol = 'M';
      case '분기점':
        symbol = '⑂';
      case '안내판또는지도':
        symbol = 'i';
      default:
        symbol = '•';
    }

    return 'data:image/svg+xml,'
        '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="${size + 10}">'
        '<path d="M${size/2} ${size + 8} L${size*0.2} ${size*0.7} Q0 ${size*0.5} 0 ${size*0.4} '
        'Q0 0 ${size/2} 0 Q$size 0 $size ${size*0.4} Q$size ${size*0.5} ${size*0.8} ${size*0.7} Z" '
        'fill="$color" stroke="$strokeColor" stroke-width="$strokeWidth"/>'
        '<text x="${size/2}" y="${size*0.5}" text-anchor="middle" fill="white" '
        'font-size="${size*0.35}" font-weight="bold" font-family="Arial">$symbol</text>'
        '</svg>';
  }

  // 등산로 로드
  Future<void> _loadTrail() async {
    try {
      final trailData = await _trailService.loadTrailDataFromSupabase(widget.oreum.id);
      if (trailData != null && mounted) {
        final polylines = <Polyline>{};

        if (trailData.trailSegments.isNotEmpty) {
          for (int i = 0; i < trailData.trailSegments.length; i++) {
            final segment = trailData.trailSegments[i];
            if (segment.length >= 2) {
              polylines.add(
                Polyline(
                  polylineId: 'trail_${widget.oreum.id}_$i',
                  points: segment,
                  strokeColor: AppColors.primary.withOpacity(0.5),
                  strokeWidth: 5,
                ),
              );
            }
          }
        } else if (trailData.trailPoints.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: 'trail_${widget.oreum.id}',
              points: trailData.trailPoints,
              strokeColor: AppColors.primary.withOpacity(0.5),
              strokeWidth: 5,
            ),
          );
        }

        // '기타' 제외한 시설물만 필터링
        debugPrint('=== 시설물 전체: ${trailData.facilities.length}개 ===');
        for (final f in trailData.facilities) {
          debugPrint('  타입: ${f.type}, 설명: ${f.description}, 위치: ${f.location}');
        }
        final facilitiesToShow = trailData.facilities
            .where((f) => f.type != '기타')
            .toList();
        debugPrint('=== 필터 후: ${facilitiesToShow.length}개 ===');

        setState(() {
          _trailPolylines = polylines;
          _currentFacilities = facilitiesToShow;
        });

        // 시설물 마커 생성
        _buildFacilityMarkers();
      }
    } catch (e) {
      debugPrint('등산로 로드 실패: $e');
    }
  }

  // 시설물 마커 생성 (선택 상태에 따라 색상 변경)
  void _buildFacilityMarkers() {
    if (_currentFacilities.isEmpty) {
      setState(() {
        _facilityMarkers = {};
      });
      return;
    }

    final markers = <Marker>{};
    for (int i = 0; i < _currentFacilities.length; i++) {
      final facility = _currentFacilities[i];
      final isSelected = _selectedFacility == facility;
      final size = isSelected ? 36 : 28; // 선택 시 더 크게
      // 선택 상태에 따라 마커 ID 변경하여 강제 업데이트
      final markerIdSuffix = isSelected ? '_selected' : '';

      final label = (facility.description ?? '').isNotEmpty
          ? '${facility.type} - ${facility.description}'
          : facility.type;
      markers.add(
        Marker(
          markerId: 'facility_$i$markerIdSuffix',
          latLng: facility.location,
          width: size,
          height: size + 10,
          markerImageSrc: _getFacilityMarkerImage(facility.type, isSelected),
          infoWindowContent: label,
        ),
      );
    }

    setState(() {
      _facilityMarkers = markers;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _mapService.stopTracking();
    _mapService.dispose();
    // 등반 중이었다면 백그라운드 서비스도 종료
    if (_isHiking) {
      BackgroundLocationService.stopService();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 앱이 백그라운드로 갈 때 (전화, 홈버튼 등) 상태 저장
      if (_isHiking) {
        _saveHikingState();
      }
    } else if (state == AppLifecycleState.resumed) {
      // 앱이 다시 포그라운드로 돌아올 때
      if (_isHiking) {
        debugPrint('등산 기록 유지 중 - 앱 복귀');
      }
    }
  }

  // 등산 상태 저장 (전화/백그라운드 시)
  Future<void> _saveHikingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hiking_active', true);
      await prefs.setString('hiking_oreum_id', widget.oreum.id);
      await prefs.setDouble('hiking_distance', _totalDistance);
      await prefs.setInt('hiking_seconds', _elapsedSeconds);
      await prefs.setInt('hiking_steps', _hikingSteps);
      await prefs.setInt('hiking_start_steps', _startSteps);
      await prefs.setDouble('hiking_max_alt', _maxAltitude);
      await prefs.setDouble('hiking_min_alt', _minAltitude == double.infinity ? 0 : _minAltitude);
      await prefs.setDouble('hiking_elev_gain', _elevationGain);
      await prefs.setDouble('hiking_elev_loss', _elevationLoss);
      await prefs.setDouble('hiking_last_alt', _lastAltitude);
      await prefs.setBool('hiking_reached_summit', _reachedSummit);
      await prefs.setInt('hiking_calories', _calculatedCalories);
      await prefs.setBool('hiking_is_descending', _isDescending);
      await prefs.setDouble('hiking_descent_dist', _descentDistance);
      await prefs.setInt('hiking_descent_secs', _descentSeconds);
      await prefs.setInt('hiking_descent_steps', _descentSteps);
      await prefs.setDouble('hiking_ascent_dist', _ascentDistance);
      await prefs.setInt('hiking_ascent_secs', _ascentSeconds);
      await prefs.setInt('hiking_ascent_steps', _ascentSteps);
      // 저장 시각 기록 (복원 시 경과 시간 보정용)
      await prefs.setInt('hiking_saved_at', DateTime.now().millisecondsSinceEpoch);
      // GPS 경로 저장 (최근 포인트들)
      final positionData = _trackPositions.map((p) =>
        '${p.latitude},${p.longitude},${p.altitude},${p.timestamp.toIso8601String()}'
      ).toList();
      await prefs.setStringList('hiking_positions', positionData);
      debugPrint('등산 상태 저장 완료 (거리: ${_totalDistance}m, 시간: ${_elapsedSeconds}s)');
    } catch (e) {
      debugPrint('등산 상태 저장 실패: $e');
    }
  }

  // 등산 상태 복원
  Future<void> _restoreHikingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('hiking_active') ?? false;
      final savedOreumId = prefs.getString('hiking_oreum_id') ?? '';

      if (!isActive || savedOreumId != widget.oreum.id) return;

      final savedAt = prefs.getInt('hiking_saved_at') ?? 0;
      if (savedAt == 0) return;

      // 경과 시간 보정
      final elapsed = DateTime.now().millisecondsSinceEpoch - savedAt;
      final additionalSeconds = elapsed ~/ 1000;

      if (!mounted) return;

      setState(() {
        _isHiking = true;
        _totalDistance = prefs.getDouble('hiking_distance') ?? 0;
        _elapsedSeconds = (prefs.getInt('hiking_seconds') ?? 0) + additionalSeconds;
        _hikingSteps = prefs.getInt('hiking_steps') ?? 0;
        _startSteps = prefs.getInt('hiking_start_steps') ?? 0;
        _maxAltitude = prefs.getDouble('hiking_max_alt') ?? 0;
        final savedMinAlt = prefs.getDouble('hiking_min_alt') ?? 0;
        _minAltitude = savedMinAlt == 0 ? double.infinity : savedMinAlt;
        _elevationGain = prefs.getDouble('hiking_elev_gain') ?? 0;
        _elevationLoss = prefs.getDouble('hiking_elev_loss') ?? 0;
        _lastAltitude = prefs.getDouble('hiking_last_alt') ?? 0;
        _reachedSummit = prefs.getBool('hiking_reached_summit') ?? false;
        _calculatedCalories = prefs.getInt('hiking_calories') ?? 0;
        _isDescending = prefs.getBool('hiking_is_descending') ?? false;
        _descentDistance = prefs.getDouble('hiking_descent_dist') ?? 0;
        _descentSeconds = (prefs.getInt('hiking_descent_secs') ?? 0) + (_isDescending ? additionalSeconds : 0);
        _descentSteps = prefs.getInt('hiking_descent_steps') ?? 0;
        _ascentDistance = prefs.getDouble('hiking_ascent_dist') ?? 0;
        _ascentSeconds = prefs.getInt('hiking_ascent_secs') ?? 0;
        _ascentSteps = prefs.getInt('hiking_ascent_steps') ?? 0;
      });

      // GPS 경로 복원
      final positionData = prefs.getStringList('hiking_positions') ?? [];
      for (final data in positionData) {
        final parts = data.split(',');
        if (parts.length >= 3) {
          _trackPositions.add(Position(
            latitude: double.parse(parts[0]),
            longitude: double.parse(parts[1]),
            altitude: double.parse(parts[2]),
            timestamp: parts.length >= 4 ? DateTime.parse(parts[3]) : DateTime.now(),
            accuracy: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ));
        }
      }

      // 경로 폴리라인 복원
      _updateTrackPolyline();

      // 걸음수 서비스 재시작
      final actStatus = await Permission.activityRecognition.status;
      if (actStatus.isGranted && mounted) {
        final pedometer = context.read<PedometerService>();
        if (!pedometer.isInitialized) {
          await pedometer.initialize();
        }
        _startSteps = pedometer.todaySteps - _hikingSteps;
      }

      // 타이머 재시작
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          final currentSteps = context.read<PedometerService>().todaySteps;
          setState(() {
            _elapsedSeconds++;
            _hikingSteps = currentSteps - _startSteps;
            if (_hikingSteps < 0) _hikingSteps = 0;

            if (_isDescending) {
              _descentSeconds++;
              _descentSteps = currentSteps - _descentStartSteps;
              if (_descentSteps < 0) _descentSteps = 0;
            }
          });
        }
      });

      // GPS 추적 재시작
      _mapService.startTracking(onPositionUpdate: _onPositionUpdate);

      debugPrint('등산 상태 복원 완료');
    } catch (e) {
      debugPrint('등산 상태 복원 실패: $e');
      await _clearHikingState();
    }
  }

  // 저장된 등산 상태 삭제
  Future<void> _clearHikingState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('hiking_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// 백그라운드 위치 권한 전체화면 공개 (Google Play 정책 필수)
  Future<bool> _requestBackgroundLocationWithDisclosure() async {
    // 이미 백그라운드 위치 권한이 있으면 바로 통과
    final bgStatus = await Permission.locationAlways.status;
    if (bgStatus.isGranted) return true;

    // 전체화면 공개 화면으로 이동 (내부에서 포그라운드 + 백그라운드 권한 요청 처리)
    if (!mounted) return false;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const BackgroundLocationPermissionScreen(),
      ),
    );
    return result == true;
  }

  /// 권한이 이미 있을 때만 위치 로드 (initState용, 권한 요청 안 함)
  Future<void> _initializeLocation() async {
    // 이미 권한이 있을 때만 위치 가져오기 (권한 요청은 등반 시작 시)
    final position = await _mapService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });
      _updateMarkers();
      _mapController?.setCenter(
        LatLng(position.latitude, position.longitude),
      );
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // 출발점 마커
    if (widget.oreum.startLat != null && widget.oreum.startLng != null) {
      markers.add(Marker(
        markerId: 'start',
        latLng: LatLng(widget.oreum.startLat!, widget.oreum.startLng!),
        infoWindowContent: '출발점',
      ));
    }

    // 정상 마커
    if (widget.oreum.summitLat != null && widget.oreum.summitLng != null) {
      markers.add(Marker(
        markerId: 'summit',
        latLng: LatLng(widget.oreum.summitLat!, widget.oreum.summitLng!),
        infoWindowContent: '정상',
      ));

      // 정상 인증 범위 원 (100m) - 등반 시작 전/중에만 표시
      if (!_isCompleted) {
        _summitRangeCircle = {
          Circle(
            circleId: 'summit_range_${widget.oreum.id}',
            center: LatLng(widget.oreum.summitLat!, widget.oreum.summitLng!),
            radius: 100,
            strokeWidth: 3,
            strokeColor: Colors.green,
            strokeOpacity: 0.8,
            strokeStyle: StrokeStyle.dash,
            fillColor: Colors.green,
            fillOpacity: 0.15,
          ),
        };
        _summitRangeLabel = {
          CustomOverlay(
            customOverlayId: 'summit_label_${widget.oreum.id}',
            latLng: LatLng(widget.oreum.summitLat!, widget.oreum.summitLng!),
            content: '<div style="background:white;padding:4px 8px;border-radius:12px;border:2px solid #4CAF50;box-shadow:0 2px 4px rgba(0,0,0,0.2);"><span style="font-size:11px;color:#2E7D32;font-weight:bold;">정상인증 가능영역</span></div>',
            xAnchor: 0.5,
            yAnchor: 0.5,
            zIndex: 10,
          ),
        };
      }
    }

    setState(() {
      _markers = markers;

      // 현재 위치 커스텀 오버레이
      if (_currentPosition != null) {
        _userLocationOverlay = {
          CustomOverlay(
            customOverlayId: 'user_location_${DateTime.now().millisecondsSinceEpoch}',
            latLng: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            content: '<div style="width:30px;height:42px;position:relative;"><div style="width:30px;height:30px;background:linear-gradient(135deg,#ff6b6b,#e53935);border:3px solid white;border-radius:50% 50% 50% 0;transform:rotate(-45deg);box-shadow:0 3px 8px rgba(0,0,0,0.4);"></div><div style="position:absolute;top:8px;left:8px;width:14px;height:14px;background:white;border-radius:50%;"></div></div>',
            xAnchor: 0.5,
            yAnchor: 1.0,
            zIndex: 100,
          ),
        };
      }
    });
  }

  void _onMarkerTap(String markerId, LatLng position, int zoomLevel) {
    // 시설물 마커인 경우 (지도 이동 없이 마커만 강조)
    if (markerId.startsWith('facility_')) {
      // facility_0, facility_0_selected 둘 다 처리
      String indexStr = markerId.replaceFirst('facility_', '');
      indexStr = indexStr.replaceAll('_selected', '');
      final index = int.tryParse(indexStr);
      if (index != null && index < _currentFacilities.length) {
        final tappedFacility = _currentFacilities[index];
        setState(() {
          // 이미 선택된 마커를 다시 클릭하면 선택 해제
          if (_selectedFacility == tappedFacility) {
            _selectedFacility = null;
          } else {
            _selectedFacility = tappedFacility;
          }
        });
        // 마커 색상 업데이트 (지도 이동 없음)
        _buildFacilityMarkers();
        return;
      }
    }

    String title = '';
    switch (markerId) {
      case 'start':
        title = '출발점';
        break;
      case 'summit':
        title = '정상';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text('${widget.oreum.name} $title'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _updateTrackPolyline() {
    if (_trackPositions.length < 2) return;

    final points = _trackPositions
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    setState(() {
      _trackPolyline = {
        Polyline(
          polylineId: 'track',
          points: points,
          strokeColor: Colors.blue,
          strokeWidth: 5,
        ),
      };
    });
  }

  void _startHiking() async {
    // 이미 시작 처리 중이면 무시 (중복 방지)
    if (_isStarting || _isHiking) return;

    // 로그인 체크
    if (!LoginGuard.check(context, message: '등산을 시작하려면 로그인이 필요합니다.\n로그인 하시겠습니까?')) return;

    setState(() => _isStarting = true);

    // 1단계: 포그라운드 위치 권한 확보 (전체화면 공개 포함)
    final fgGranted = await MapService.ensureLocationPermission(context);
    if (!fgGranted) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등산을 시작하려면 위치 권한이 필요합니다')),
        );
      }
      return;
    }

    // 2단계: 백그라운드 위치 권한 확보 (전체화면 공개 포함)
    final bgGranted = await _requestBackgroundLocationWithDisclosure();

    if (!mounted) return;

    // 걸음수 권한 요청 및 초기화
    final actStatus = await Permission.activityRecognition.request();
    if (actStatus.isGranted && mounted) {
      final pedometer = context.read<PedometerService>();
      if (!pedometer.isInitialized) {
        await pedometer.initialize();
      }
    }

    if (!mounted) return;

    // 권한 획득 후 현재 위치 갱신
    final position = await _mapService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });
      _updateMarkers();
      _mapController?.setCenter(
        LatLng(position.latitude, position.longitude),
      );
    }

    // 시작 걸음수 기록
    final pedometer = context.read<PedometerService>();
    _startSteps = pedometer.todaySteps;

    setState(() {
      _isStarting = false;
      _isHiking = true;
      _isPaused = false;
      _trackPositions = [];
      _totalDistance = 0;
      _elapsedSeconds = 0;
      _hikingSteps = 0;
      // 고도 초기화
      _maxAltitude = 0;
      _minAltitude = double.infinity;
      _elevationGain = 0;
      _elevationLoss = 0;
      _lastAltitude = 0;
      _currentAltitude = 0;
      _calculatedCalories = 0;
    });

    // 시설물 마커 상태 유지 (선택된 마커 색상 유지)
    _buildFacilityMarkers();

    // 백그라운드 서비스 시작 (권한 있을 때만)
    if (bgGranted) {
      BackgroundLocationService.startService();
    }

    // 타이머 시작 (걸음수도 함께 업데이트)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        final currentSteps = context.read<PedometerService>().todaySteps;
        setState(() {
          _elapsedSeconds++;
          _hikingSteps = currentSteps - _startSteps;
          if (_hikingSteps < 0) _hikingSteps = 0;

          if (_isDescending) {
            _descentSeconds++;
            _descentSteps = currentSteps - _descentStartSteps;
            if (_descentSteps < 0) _descentSteps = 0;
          }
        });
      }
    });

    // GPS 추적 시작
    _mapService.startTracking(
      onPositionUpdate: _onPositionUpdate,
    );
  }

  void _onPositionUpdate(Position position) {
    if (!mounted || _isPaused) return;

    setState(() {
      _currentPosition = position;

      // 이전 위치가 있으면 거리 계산
      if (_trackPositions.isNotEmpty) {
        final lastPos = _trackPositions.last;
        final distance = _mapService.calculateDistance(
          lastPos.latitude,
          lastPos.longitude,
          position.latitude,
          position.longitude,
        );
        if (_isDescending) {
          _descentDistance += distance;
        } else {
          _totalDistance += distance;
        }
      }

      // 고도 추적
      final altitude = position.altitude;
      if (altitude > 0 && altitude < 10000) { // 유효한 고도값만 처리
        _currentAltitude = altitude;

        if (_trackPositions.isNotEmpty && _lastAltitude > 0) {
          final altDiff = altitude - _lastAltitude;
          // 노이즈 필터링: 2m 이상 차이만 반영
          if (altDiff.abs() > 2) {
            if (_isDescending) {
              if (altDiff > 0) {
                _descentElevationGain += altDiff;
              } else {
                _descentElevationLoss += altDiff.abs();
              }
            } else {
              if (altDiff > 0) {
                _elevationGain += altDiff;
              } else {
                _elevationLoss += altDiff.abs();
              }
            }
          }
        }

        if (altitude > _maxAltitude) _maxAltitude = altitude;
        if (altitude < _minAltitude) _minAltitude = altitude;
        _lastAltitude = altitude;
      }

      _trackPositions.add(position);

      // 정상까지 남은 거리 계산
      if (widget.oreum.summitLat != null && widget.oreum.summitLng != null) {
        _distanceToSummit = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.oreum.summitLat!,
          widget.oreum.summitLng!,
        );
      }
    });

    _updateMarkers();
    _updateTrackPolyline();

    // 지도 중심 이동
    _mapController?.setCenter(
      LatLng(position.latitude, position.longitude),
    );

    // 정상 도착 확인 (등산 중일 때만)
    if (!_isDescending) {
      _checkSummitArrival(position);
    } else {
      // 하산 중 입구 근처 도착 감지
      _checkStartPointArrival(position);
    }
  }

  void _checkStartPointArrival(Position position) {
    if (_descentDialogShown) return;
    if (widget.oreum.startLat == null || widget.oreum.startLng == null) return;

    final distanceToStart = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.oreum.startLat!,
      widget.oreum.startLng!,
    );

    if (distanceToStart <= 100) {
      _descentDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.home, color: AppColors.primary),
              SizedBox(width: 8),
              Text('입구 도착!'),
            ],
          ),
          content: const Text('출발점 근처에 도착했습니다.\n하산을 완료하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('계속 이동'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _completeHiking();
              },
              child: const Text('하산 완료'),
            ),
          ],
        ),
      );
    }
  }

  void _checkSummitArrival(Position position) {
    if (widget.oreum.summitLat == null || widget.oreum.summitLng == null) return;

    // 100m 이내면 정상 도착으로 인정
    final distanceToSummit = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.oreum.summitLat!,
      widget.oreum.summitLng!,
    );

    if (distanceToSummit <= 100 && !_reachedSummit) {
      setState(() {
        _reachedSummit = true;
      });
    }

    // 50m 이내면 완료 다이얼로그 표시 (1회만)
    if (distanceToSummit <= 50 && !_isCompleted && !_summitDialogShown) {
      _summitDialogShown = true;
      _showSummitDialog();
    }
  }

  void _showSummitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag, color: AppColors.primary),
            SizedBox(width: 8),
            Text('정상 도착!'),
          ],
        ),
        content: Text('${widget.oreum.name} 정상에 도착했습니다!\n하산을 시작하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속 등반'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startDescent();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('하산 시작'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeHiking();
            },
            child: const Text('여기서 완료'),
          ),
        ],
      ),
    );
  }

  void _startDescent() {
    final pedometer = context.read<PedometerService>();
    setState(() {
      // 등산 데이터 스냅샷 저장
      _ascentDistance = _totalDistance;
      _ascentSeconds = _elapsedSeconds;
      _ascentSteps = _hikingSteps;

      // 하산 모드 전환
      _isDescending = true;
      _descentDistance = 0;
      _descentSeconds = 0;
      _descentSteps = 0;
      _descentStartSteps = pedometer.todaySteps;
      _descentElevationGain = 0;
      _descentElevationLoss = 0;
      _descentCalories = 0;
      _descentDialogShown = false;
    });
  }

  void _pauseHiking() {
    setState(() {
      _isPaused = true;
    });
    _mapService.stopTracking();
  }

  void _resumeHiking() {
    setState(() {
      _isPaused = false;
    });
    _mapService.startTracking(onPositionUpdate: _onPositionUpdate);
  }

  Future<void> _completeHiking() async {
    if (_isCompleted) return;
    _isCompleted = true; // 즉시 설정하여 중복 호출 방지

    _timer?.cancel();
    await _clearHikingState(); // 저장된 임시 상태 삭제
    _mapService.stopTracking();

    // 저장 중 로딩 표시
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    // 백그라운드에서 측정된 걸음수 동기화
    final pedometer = context.read<PedometerService>();
    await pedometer.syncFromBackground();
    final currentSteps = pedometer.todaySteps;
    _hikingSteps = currentSteps - _startSteps;
    if (_hikingSteps < 0) _hikingSteps = 0;

    // 백그라운드 위치 서비스 종료
    await BackgroundLocationService.stopService();

    setState(() {
      _isHiking = false;
    });

    // 하산 중이었다면 등산 데이터는 스냅샷 사용
    final ascentDist = _isDescending ? _ascentDistance : _totalDistance;
    final ascentSecs = _isDescending ? _ascentSeconds : _elapsedSeconds;
    final ascentSteps = _isDescending ? _ascentSteps : _hikingSteps;

    // 평균 속도 계산 (등산 구간)
    final avgSpeed = ascentSecs > 0
        ? (ascentDist / 1000) / (ascentSecs / 3600)
        : 0.0;

    // 칼로리 계산
    final authProvider = context.read<AuthProvider>();
    final userWeight = authProvider.weight ?? 70.0;
    _calculatedCalories = CalorieCalculator.calculateHikingCalories(
      distanceKm: ascentDist / 1000,
      durationMinutes: ascentSecs ~/ 60,
      elevationGainM: _elevationGain,
      elevationLossM: _elevationLoss,
      weightKg: userWeight,
    );

    // 하산 칼로리 계산
    if (_isDescending && _descentDistance > 0) {
      _descentCalories = CalorieCalculator.calculateHikingCalories(
        distanceKm: _descentDistance / 1000,
        durationMinutes: _descentSeconds ~/ 60,
        elevationGainM: _descentElevationGain,
        elevationLossM: _descentElevationLoss,
        weightKg: userWeight,
      );
    }

    // 사진 업로드
    List<String> photoUrls = [];
    if (_hikingPhotos.isNotEmpty) {
      for (final photo in _hikingPhotos) {
        try {
          final url = await _hikingRouteService.uploadHikingPhoto(
            photo.path,
            widget.oreum.id,
          );
          photoUrls.add(url);
        } catch (e) {
          debugPrint('사진 업로드 실패: $e');
        }
      }
    }

    // 정상 100m 이내를 지나지 않았으면 스탬프 저장 안함
    if (!_reachedSummit) {
      // 등반 기록만 저장 (hiking_logs 테이블)
      try {
        final logId = await _stampService.recordHikingLog(
          oreumId: widget.oreum.id,
          distanceWalked: ascentDist,
          timeTaken: ascentSecs ~/ 60,
          steps: ascentSteps,
          avgSpeed: avgSpeed,
          calories: _calculatedCalories,
          elevationGain: _elevationGain,
          elevationLoss: _elevationLoss,
          maxAltitude: _maxAltitude > 0 ? _maxAltitude : null,
          minAltitude: _minAltitude < double.infinity ? _minAltitude : null,
          descentDistance: _isDescending ? _descentDistance : null,
          descentTime: _isDescending ? _descentSeconds ~/ 60 : null,
          descentSteps: _isDescending ? _descentSteps : null,
          descentCalories: _isDescending ? _descentCalories : null,
        );

        // GPS 경로 저장 (미완등 시에도 저장)
        if (logId != null && _trackPositions.isNotEmpty) {
          try {
            await _hikingRouteService.saveRoute(
              hikingLogId: logId,
              oreumId: widget.oreum.id,
              positions: _trackPositions,
              photoUrls: photoUrls.isNotEmpty ? photoUrls : null,
            );
          } catch (e) {
            debugPrint('경로 저장 실패: $e');
          }
        }
      } catch (e) {
        debugPrint('등반 기록 저장 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기록 저장에 실패했습니다.'), duration: Duration(seconds: 5)),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        _showIncompleteDialog();
      }
      return;
    }

    // 등반 기록 저장 (stamps 테이블) - 정상 도착 시에만
    try {
      final stampId = await _stampService.recordStamp(
        oreumId: widget.oreum.id,
        distanceWalked: ascentDist,
        timeTaken: ascentSecs ~/ 60,
        steps: ascentSteps,
        avgSpeed: avgSpeed,
        calories: _calculatedCalories,
        elevationGain: _elevationGain,
        elevationLoss: _elevationLoss,
        maxAltitude: _maxAltitude > 0 ? _maxAltitude : null,
        minAltitude: _minAltitude < double.infinity ? _minAltitude : null,
        descentDistance: _isDescending ? _descentDistance : null,
        descentTime: _isDescending ? _descentSeconds ~/ 60 : null,
        descentSteps: _isDescending ? _descentSteps : null,
        descentCalories: _isDescending ? _descentCalories : null,
      );

      // GPS 경로 저장
      if (stampId != null && _trackPositions.isNotEmpty) {
        try {
          await _hikingRouteService.saveRoute(
            stampId: stampId,
            oreumId: widget.oreum.id,
            positions: _trackPositions,
            photoUrls: photoUrls.isNotEmpty ? photoUrls : null,
          );
        } catch (e) {
          debugPrint('경로 저장 실패: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        _showCompletionDialog();
      }
    } catch (e) {
      debugPrint('에러: $e');
      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _showIncompleteDialog() {
    final ascentDist = _isDescending ? _ascentDistance : _totalDistance;
    final ascentSecs = _isDescending ? _ascentSeconds : _elapsedSeconds;
    final memoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_isDescending ? '하산 종료' : '등반 종료'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hiking,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                '정상을 지나지 않아\n완등으로 기록되지 않았어요.\n등산 기록은 저장됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              // 메모 입력
              TextField(
                controller: memoController,
                decoration: InputDecoration(
                  hintText: '메모 추가 (예: 산책만)',
                  prefixIcon: const Icon(Icons.edit_note, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLength: 30,
              ),
              const SizedBox(height: 8),
              _buildStatRow('등산 거리', '${(ascentDist / 1000).toStringAsFixed(2)} km'),
              _buildStatRow('등산 시간', _formatDuration(ascentSecs)),
              if (_isDescending && _descentDistance > 0) ...[
                const Divider(),
                _buildStatRow('하산 거리', '${(_descentDistance / 1000).toStringAsFixed(2)} km'),
                _buildStatRow('하산 시간', _formatDuration(_descentSeconds)),
                const Divider(),
                _buildStatRow('총 거리', '${((ascentDist + _descentDistance) / 1000).toStringAsFixed(2)} km'),
                _buildStatRow('총 시간', _formatDuration(_elapsedSeconds)),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final memo = memoController.text.trim();
              if (memo.isNotEmpty) {
                _saveMemo(memo);
              }
              // 스탬프 목록 새로고침
              context.read<StampProvider>().loadStamps();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    final ascentDist = _isDescending ? _ascentDistance : _totalDistance;
    final ascentSecs = _isDescending ? _ascentSeconds : _elapsedSeconds;
    final ascentStepsVal = _isDescending ? _ascentSteps : _hikingSteps;
    final memoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_isDescending ? '등반+하산 완료!' : '등반 완료!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.celebration,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.oreum.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // 메모 입력
              TextField(
                controller: memoController,
                decoration: InputDecoration(
                  hintText: '메모 추가 (예: 친구와 함께)',
                  prefixIcon: const Icon(Icons.edit_note, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLength: 30,
              ),
              const SizedBox(height: 8),
              // 등산 통계
              if (_isDescending) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('등산', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(height: 4),
              ],
              _buildStatRow('걸음수', '${_formatNumber(ascentStepsVal)} 보'),
              _buildStatRow('이동 거리', '${(ascentDist / 1000).toStringAsFixed(2)} km'),
              _buildStatRow('소요 시간', _formatDuration(ascentSecs)),
              // 하산 통계
              if (_isDescending && _descentDistance > 0) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('하산', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                ),
                const SizedBox(height: 4),
                _buildStatRow('걸음수', '${_formatNumber(_descentSteps)} 보'),
                _buildStatRow('이동 거리', '${(_descentDistance / 1000).toStringAsFixed(2)} km'),
                _buildStatRow('소요 시간', _formatDuration(_descentSeconds)),
                const SizedBox(height: 12),
                const Divider(),
                _buildStatRow('총 거리', '${((ascentDist + _descentDistance) / 1000).toStringAsFixed(2)} km'),
                _buildStatRow('총 시간', _formatDuration(_elapsedSeconds)),
                _buildStatRow('총 걸음수', '${_formatNumber(ascentStepsVal + _descentSteps)} 보'),
              ] else ...[
                _buildStatRow('평균 속도', ascentSecs > 0
                    ? '${((ascentDist / 1000) / (ascentSecs / 3600)).toStringAsFixed(1)} km/h'
                    : '0.0 km/h'),
              ],
              const SizedBox(height: 8),
              const Text(
                '스탬프가 저장되었습니다!',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _shareRecord(),
            icon: const Icon(Icons.share),
            label: const Text('공유'),
          ),
          ElevatedButton(
            onPressed: () {
              // 메모 저장
              final memo = memoController.text.trim();
              if (memo.isNotEmpty) {
                _saveMemo(memo);
              }
              // 스탬프 목록 새로고침
              context.read<StampProvider>().loadStamps();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareRecord() async {
    // 사진이 있으면 첫번째 사진 선택, 없으면 null
    File? selectedPhoto = _hikingPhotos.isNotEmpty ? _hikingPhotos.first : null;
    await _showShareToggleOptions(selectedPhoto);
  }

  // 통합 공유 화면: 사진 선택 + 토글 옵션 + 미리보기 + 공유
  Future<void> _showShareToggleOptions(File? photo) async {
    final toggles = {
      'route': true,
      'time': true,
      'distance': true,
      'steps': true,
      'calories': true,
      'altitude': true,
      'date': true,
    };
    bool isSharing = false;

    File? selectedPhoto = photo;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // 핸들바
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '공유 카드 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // 미리보기 + 토글
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // 카드 미리보기
                          GestureDetector(
                            onTap: _hikingPhotos.length > 1 ? () async {
                              final picked = await _selectPhotoForShare();
                              if (picked != null) {
                                setModalState(() => selectedPhoto = picked);
                              }
                            } : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: double.infinity,
                                height: 280,
                                child: selectedPhoto != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildPhotoShareCardPreview(
                                            photo: selectedPhoto!,
                                            showRoute: toggles['route']!,
                                            showTime: toggles['time']!,
                                            showDistance: toggles['distance']!,
                                            showSteps: toggles['steps']!,
                                            showCalories: toggles['calories']!,
                                            showAltitude: toggles['altitude']!,
                                            showDate: toggles['date']!,
                                          ),
                                          if (_hikingPhotos.length > 1)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.photo_library, color: Colors.white, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${_hikingPhotos.length}',
                                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.terrain, size: 48, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text(
                                              widget.oreum.name,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 사진 선택 썸네일 (여러 장일 때)
                          if (_hikingPhotos.length > 1) ...[
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _hikingPhotos.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final isSelected = selectedPhoto == _hikingPhotos[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() => selectedPhoto = _hikingPhotos[index]);
                                    },
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(_hikingPhotos[index], fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // 토글 옵션들
                          if (selectedPhoto != null)
                            _buildToggleTile('GPS 경로', Icons.route, toggles['route']!, (v) {
                              setModalState(() => toggles['route'] = v);
                            }),
                          _buildToggleTile('날짜', Icons.calendar_today, toggles['date']!, (v) {
                            setModalState(() => toggles['date'] = v);
                          }),
                          _buildToggleTile('시간', Icons.schedule, toggles['time']!, (v) {
                            setModalState(() => toggles['time'] = v);
                          }),
                          _buildToggleTile('거리', Icons.straighten, toggles['distance']!, (v) {
                            setModalState(() => toggles['distance'] = v);
                          }),
                          _buildToggleTile('걸음수', Icons.directions_walk, toggles['steps']!, (v) {
                            setModalState(() => toggles['steps'] = v);
                          }),
                          _buildToggleTile('칼로리', Icons.local_fire_department, toggles['calories']!, (v) {
                            setModalState(() => toggles['calories'] = v);
                          }),
                          _buildToggleTile('고도', Icons.trending_up, toggles['altitude']!, (v) {
                            setModalState(() => toggles['altitude'] = v);
                          }),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // 공유하기 버튼
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20, right: 20, bottom: MediaQuery.of(sheetContext).padding.bottom + 16, top: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSharing ? null : () async {
                          setModalState(() => isSharing = true);
                          try {
                            final now = DateTime.now();
                            final dateStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

                            Widget shareWidget;
                            if (selectedPhoto != null) {
                              shareWidget = _buildPhotoShareCard(
                                photo: selectedPhoto!,
                                date: dateStr,
                                showRoute: toggles['route']!,
                                showTime: toggles['time']!,
                                showDistance: toggles['distance']!,
                                showSteps: toggles['steps']!,
                                showCalories: toggles['calories']!,
                                showAltitude: toggles['altitude']!,
                                showDate: toggles['date']!,
                              );
                            } else {
                              shareWidget = _buildRouteShareCard(
                                date: dateStr,
                                showRoute: toggles['route']!,
                                showTime: toggles['time']!,
                                showDistance: toggles['distance']!,
                                showSteps: toggles['steps']!,
                                showCalories: toggles['calories']!,
                                showAltitude: toggles['altitude']!,
                                showDate: toggles['date']!,
                              );
                            }

                            final shareService = ShareService();
                            final imagePath = await shareService.captureWidget(widget: shareWidget);

                            if (!mounted) return;
                            Navigator.pop(sheetContext);

                            await shareService.shareImage(
                              imagePath: imagePath,
                              oreumName: widget.oreum.name,
                              text: '${widget.oreum.name} 등반 완료!\n#JEJUOREUM #등산',
                            );
                          } catch (e) {
                            setModalState(() => isSharing = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('공유에 실패했습니다. 다시 시도해주세요.')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSharing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('공유하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToggleTile(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // 미리보기용 (인라인 크기)
  Widget _buildPhotoShareCardPreview({
    required File photo,
    bool showRoute = true,
    bool showTime = true,
    bool showDistance = true,
    bool showSteps = true,
    bool showCalories = true,
    bool showAltitude = true,
    bool showDate = true,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    // 선택된 항목들로 정보 문자열 생성
    final infoParts = <String>[];
    if (showDistance) infoParts.add('${(_totalDistance / 1000).toStringAsFixed(2)}km');
    if (showTime) infoParts.add(_formatDuration(_elapsedSeconds));
    if (showSteps) infoParts.add('$_hikingSteps걸음');
    if (showCalories) infoParts.add('${_calculatedCalories}kcal');
    if (showAltitude) infoParts.add('+${_elevationGain.toStringAsFixed(0)}m');
    if (showDate) infoParts.add(dateStr);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(photo, fit: BoxFit.cover),
        // 그라데이션
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.15),
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
        ),
        // GPS 경로 오버레이
        if (showRoute && _trackPositions.length >= 2)
          Positioned.fill(
            child: CustomPaint(
              painter: RoutePainter(
                positions: _trackPositions,
                strokeColor: Colors.white,
                strokeWidth: 2.0,
              ),
            ),
          ),
        // 상단 워터마크
        Positioned(
          top: 12,
          right: 12,
          child: Text(
            'JEJUOREUM',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ),
        // 하단 오름 이름 + 정보
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.oreum.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (infoParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    infoParts.join('  |  '),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 사진 선택 다이얼로그
  Future<File?> _selectPhotoForShare() async {
    File? selected;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '공유할 사진 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _hikingPhotos.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () {
                    selected = _hikingPhotos[index];
                    Navigator.pop(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _hikingPhotos[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return selected;
  }

  // 사진 위에 통계 오버레이 카드 (oreumpass 스타일, 토글 지원)
  Widget _buildPhotoShareCard({
    required File photo,
    required String date,
    bool showRoute = true,
    bool showTime = true,
    bool showDistance = true,
    bool showSteps = true,
    bool showCalories = true,
    bool showAltitude = true,
    bool showDate = true,
  }) {
    // 선택된 항목들로 정보 문자열 생성
    final infoParts = <String>[];
    if (showDistance) infoParts.add('${(_totalDistance / 1000).toStringAsFixed(2)}km');
    if (showTime) infoParts.add(_formatDuration(_elapsedSeconds));
    if (showSteps) infoParts.add('$_hikingSteps걸음');
    if (showCalories) infoParts.add('${_calculatedCalories}kcal');
    if (showAltitude) infoParts.add('+${_elevationGain.toStringAsFixed(0)}m');
    if (showDate) infoParts.add(date);

    return Container(
      width: 400,
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 사진 (전체)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              photo,
              fit: BoxFit.cover,
            ),
          ),
          // 그라데이션 오버레이
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),
          // GPS 경로 오버레이
          if (showRoute && _trackPositions.length >= 2)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                size: const Size(400, 500),
                painter: RoutePainter(
                  positions: _trackPositions,
                  strokeColor: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          // 상단 워터마크
          Positioned(
            top: 16,
            right: 16,
            child: Text(
              'JEJUOREUM',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
          ),
          // 하단 오름 이름 + 선택된 정보
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 오름 이름 크게
                  Text(
                    widget.oreum.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (infoParts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      infoParts.join('  |  '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 경로 + 통계 카드 공유 (토글 옵션 포함)
  Future<void> _shareRouteCard() async {
    final toggles = {
      'route': true,
      'time': true,
      'distance': true,
      'steps': true,
      'calories': true,
      'altitude': true,
      'date': true,
    };
    bool isSharing = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final now = DateTime.now();
            final dateStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '공유 카드 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // 미리보기
                          _buildRouteShareCard(
                            date: dateStr,
                            showRoute: toggles['route']!,
                            showTime: toggles['time']!,
                            showDistance: toggles['distance']!,
                            showSteps: toggles['steps']!,
                            showCalories: toggles['calories']!,
                            showAltitude: toggles['altitude']!,
                            showDate: toggles['date']!,
                          ),
                          const SizedBox(height: 20),
                          _buildToggleTile('GPS 경로', Icons.route, toggles['route']!, (v) {
                            setModalState(() => toggles['route'] = v);
                          }),
                          _buildToggleTile('날짜', Icons.calendar_today, toggles['date']!, (v) {
                            setModalState(() => toggles['date'] = v);
                          }),
                          _buildToggleTile('시간', Icons.schedule, toggles['time']!, (v) {
                            setModalState(() => toggles['time'] = v);
                          }),
                          _buildToggleTile('거리', Icons.straighten, toggles['distance']!, (v) {
                            setModalState(() => toggles['distance'] = v);
                          }),
                          _buildToggleTile('걸음수', Icons.directions_walk, toggles['steps']!, (v) {
                            setModalState(() => toggles['steps'] = v);
                          }),
                          _buildToggleTile('칼로리', Icons.local_fire_department, toggles['calories']!, (v) {
                            setModalState(() => toggles['calories'] = v);
                          }),
                          _buildToggleTile('고도', Icons.trending_up, toggles['altitude']!, (v) {
                            setModalState(() => toggles['altitude'] = v);
                          }),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20, right: 20, bottom: MediaQuery.of(sheetContext).padding.bottom + 16, top: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSharing ? null : () async {
                          setModalState(() => isSharing = true);
                          try {
                            final shareWidget = _buildRouteShareCard(
                              date: dateStr,
                              showRoute: toggles['route']!,
                              showTime: toggles['time']!,
                              showDistance: toggles['distance']!,
                              showSteps: toggles['steps']!,
                              showCalories: toggles['calories']!,
                              showAltitude: toggles['altitude']!,
                              showDate: toggles['date']!,
                            );
                            final shareService = ShareService();
                            final imagePath = await shareService.captureWidget(widget: shareWidget);
                            if (!mounted) return;
                            Navigator.pop(sheetContext);
                            await shareService.shareImage(
                              imagePath: imagePath,
                              oreumName: widget.oreum.name,
                              text: '${widget.oreum.name} 등반 완료!\n#JEJUOREUM #등산',
                            );
                          } catch (e) {
                            setModalState(() => isSharing = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('공유에 실패했습니다.')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSharing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('공유하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 경로 공유 카드 위젯
  Widget _buildRouteShareCard({
    required String date,
    bool showRoute = true,
    bool showTime = true,
    bool showDistance = true,
    bool showSteps = true,
    bool showCalories = true,
    bool showAltitude = true,
    bool showDate = true,
  }) {
    final statItems = <Widget>[];
    if (showDistance) statItems.add(Expanded(child: _buildRouteStatItem(Icons.straighten, '${(_totalDistance / 1000).toStringAsFixed(2)} km', '거리')));
    if (showTime) statItems.add(Expanded(child: _buildRouteStatItem(Icons.schedule, _formatDuration(_elapsedSeconds), '시간')));
    if (showSteps) statItems.add(Expanded(child: _buildRouteStatItem(Icons.directions_walk, '$_hikingSteps', '걸음수')));
    if (showCalories) statItems.add(Expanded(child: _buildRouteStatItem(Icons.local_fire_department, '$_calculatedCalories kcal', '칼로리')));
    if (showAltitude) statItems.add(Expanded(child: _buildRouteStatItem(Icons.trending_up, '+${_elevationGain.toStringAsFixed(0)} m', '상승')));

    // 2개씩 Row로 묶기
    final statRows = <Widget>[];
    for (int i = 0; i < statItems.length; i += 2) {
      if (i + 1 < statItems.length) {
        statRows.add(Row(children: [statItems[i], const SizedBox(width: 8), statItems[i + 1]]));
      } else {
        statRows.add(Row(children: [statItems[i], const SizedBox(width: 8), const Expanded(child: SizedBox())]));
      }
      if (i + 2 < statItems.length) statRows.add(const SizedBox(height: 8));
    }

    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단 헤더
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.oreum.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showDate)
                      Text(
                        date,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'JEJUOREUM',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          // 경로 미니맵
          if (showRoute) ...[
            const SizedBox(height: 20),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  size: const Size(double.infinity, 180),
                  painter: RoutePainter(positions: _trackPositions),
                ),
              ),
            ),
          ],
          if (statRows.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...statRows,
          ],
          const SizedBox(height: 16),
          // 해시태그
          Text(
            '#JEJUOREUM #등산 #오름탐험',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatItem(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 기본 카드 공유 (토글 옵션 포함)
  Future<void> _shareBasicCard() async {
    final toggles = {
      'time': true,
      'distance': true,
      'steps': true,
      'calories': true,
      'altitude': true,
      'date': true,
    };
    bool isSharing = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final now = DateTime.now();
            final dateStr = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '공유 카드 설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // 미리보기
                          HikingShareCard(
                            oreumName: widget.oreum.name,
                            date: dateStr,
                            distanceKm: toggles['distance']! ? _totalDistance / 1000 : null,
                            durationMinutes: toggles['time']! ? _elapsedSeconds ~/ 60 : null,
                            steps: toggles['steps']! ? _hikingSteps : null,
                            routePoints: _trackPositions.length >= 2
                                ? _trackPositions.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _buildToggleTile('날짜', Icons.calendar_today, toggles['date']!, (v) {
                            setModalState(() => toggles['date'] = v);
                          }),
                          _buildToggleTile('시간', Icons.schedule, toggles['time']!, (v) {
                            setModalState(() => toggles['time'] = v);
                          }),
                          _buildToggleTile('거리', Icons.straighten, toggles['distance']!, (v) {
                            setModalState(() => toggles['distance'] = v);
                          }),
                          _buildToggleTile('걸음수', Icons.directions_walk, toggles['steps']!, (v) {
                            setModalState(() => toggles['steps'] = v);
                          }),
                          _buildToggleTile('칼로리', Icons.local_fire_department, toggles['calories']!, (v) {
                            setModalState(() => toggles['calories'] = v);
                          }),
                          _buildToggleTile('고도', Icons.trending_up, toggles['altitude']!, (v) {
                            setModalState(() => toggles['altitude'] = v);
                          }),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20, right: 20, bottom: MediaQuery.of(sheetContext).padding.bottom + 16, top: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSharing ? null : () async {
                          setModalState(() => isSharing = true);
                          try {
                            final shareCard = HikingShareCard(
                              oreumName: widget.oreum.name,
                              date: dateStr,
                              distanceKm: toggles['distance']! ? _totalDistance / 1000 : null,
                              durationMinutes: toggles['time']! ? _elapsedSeconds ~/ 60 : null,
                              steps: toggles['steps']! ? _hikingSteps : null,
                              routePoints: _trackPositions.length >= 2
                                  ? _trackPositions.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()
                                  : null,
                            );
                            final shareService = ShareService();
                            final imagePath = await shareService.captureWidget(widget: shareCard);
                            if (!mounted) return;
                            Navigator.pop(sheetContext);
                            await shareService.shareImage(
                              imagePath: imagePath,
                              oreumName: widget.oreum.name,
                              text: '${widget.oreum.name} 등반 완료!\n#JEJUOREUM #등산',
                            );
                          } catch (e) {
                            setModalState(() => isSharing = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('공유에 실패했습니다.')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSharing
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('공유하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 메모 저장 (최근 저장된 기록에 memo 추가)
  Future<void> _saveMemo(String memo) async {
    try {
      await _stampService.updateLatestRecordMemo(
        oreumId: widget.oreum.id,
        memo: memo,
      );
    } catch (e) {
      debugPrint('메모 저장 실패: $e');
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _stopHiking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isDescending ? '하산 중단' : '등반 중단'),
        content: Text(_isDescending
            ? '하산을 중단하시겠습니까?\n현재까지의 기록이 저장됩니다.'
            : '등반을 중단하시겠습니까?\n현재까지의 기록이 저장됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeHiking(); // 기록 저장 후 종료
            },
            child: const Text('중단 및 저장'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isHiking,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isHiking) {
          _stopHiking();
        }
      },
      child: Scaffold(
      body: Stack(
        children: [
          // 지도 (캡처용 RepaintBoundary)
          RepaintBoundary(
            key: _mapKey,
            child: KakaoMap(
              onMapCreated: (controller) async {
                _mapController = controller;
                // 내 위치 우선으로 지도 중심 설정
                if (_currentPosition != null) {
                  controller.setCenter(
                    LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  );
                } else {
                  // 위치가 아직 없으면 다시 가져와서 설정
                  final position = await _mapService.getCurrentPosition();
                  if (position != null && mounted) {
                    setState(() {
                      _currentPosition = position;
                    });
                    controller.setCenter(
                      LatLng(position.latitude, position.longitude),
                    );
                    _updateMarkers();
                  } else if (widget.oreum.startLat != null) {
                    controller.setCenter(
                      LatLng(widget.oreum.startLat!, widget.oreum.startLng!),
                    );
                  }
                }
              },
              center: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : (widget.oreum.startLat != null
                      ? LatLng(widget.oreum.startLat!, widget.oreum.startLng!)
                      : LatLng(33.3617, 126.5292)),
              currentLevel: 3,
              markers: [..._markers, ..._facilityMarkers].toList(),
              customOverlays: [..._summitRangeLabel, ..._userLocationOverlay].toList(),
              circles: _summitRangeCircle.toList(),
              polylines: [..._trailPolylines, ..._trackPolyline].toList(), // 등산로 + 추적경로
              onMarkerTap: _onMarkerTap,
            ),
          ),

          // 상단 바
          _buildTopBar(),

          // 시설물 목록 패널
          if (_currentFacilities.isNotEmpty) _buildFacilityListPanel(),

          // 카메라 버튼 (등반 중일 때만)
          if (_isHiking && !_isCompleted) _buildCameraButton(),

          // 촬영된 사진 미리보기
          if (_hikingPhotos.isNotEmpty && _isHiking) _buildPhotoPreview(),

          // 하단 컨트롤
          _buildBottomControls(),
        ],
      ),
    ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isHiking) {
                        _stopHiking();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.oreum.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isHiking)
                          Text(
                            _isPaused ? '일시정지' : (_isDescending ? '하산 중' : '등반 중'),
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPaused ? Colors.orange : (_isDescending ? Colors.orange : AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OreumDetailScreen(oreum: widget.oreum),
                        ),
                      );
                    },
                    child: Tooltip(
                      message: '오름 상세정보',
                      child: Icon(
                        Icons.info_outline,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OreumErrorReportScreen(
                            oreum: widget.oreum,
                            initialLatitude: _currentPosition?.latitude,
                            initialLongitude: _currentPosition?.longitude,
                          ),
                        ),
                      );
                    },
                    child: Tooltip(
                      message: '정보 오류 신고',
                      child: Icon(
                        Icons.report_problem_outlined,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isHiking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isPaused ? Colors.orange : (_isDescending ? Colors.orange : AppColors.primary),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isDescending ? _formatDuration(_descentSeconds) : _formatDuration(_elapsedSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (_isHiking) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showDetailedStats(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _isDescending
                        ? [
                            _buildStatItem(
                              Icons.directions_walk,
                              _formatNumber(_descentSteps),
                              '하산 걸음수',
                            ),
                            _buildStatItem(
                              Icons.straighten,
                              '${(_descentDistance / 1000).toStringAsFixed(2)} km',
                              '하산 거리',
                            ),
                            _buildStatItem(
                              Icons.schedule,
                              _formatDuration(_descentSeconds),
                              '하산 시간',
                            ),
                            _buildStatItem(
                              Icons.terrain,
                              '${((_ascentDistance + _descentDistance) / 1000).toStringAsFixed(2)} km',
                              '총 거리',
                            ),
                          ]
                        : [
                            _buildStatItem(
                              Icons.directions_walk,
                              _formatNumber(_hikingSteps),
                              '걸음수',
                            ),
                            _buildStatItem(
                              Icons.straighten,
                              '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                              '이동 거리',
                            ),
                            _buildStatItem(
                              Icons.flag,
                              _distanceToSummit > 1000
                                  ? '${(_distanceToSummit / 1000).toStringAsFixed(1)}km'
                                  : '${_distanceToSummit.toInt()}m',
                              '남은 거리',
                            ),
                            _buildStatItem(
                              Icons.schedule,
                              _getEstimatedRemainingTime(),
                              '남은 시간',
                            ),
                          ],
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('탭하여 상세 정보 보기',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // 예상 남은 시간 계산
  String _getEstimatedRemainingTime() {
    // 충분한 데이터가 있으면 실제 속도 기반 계산
    if (_totalDistance > 100 && _elapsedSeconds > 60) {
      // 평균 속도 (m/s)
      final avgSpeed = _totalDistance / _elapsedSeconds;
      if (avgSpeed > 0) {
        final remainingSeconds = (_distanceToSummit / avgSpeed).round();
        return _formatDuration(remainingSeconds);
      }
    }

    // 데이터 부족 시 오름 기본 소요시간 사용
    final defaultTimeUp = widget.oreum.timeUp;
    if (defaultTimeUp != null && defaultTimeUp > 0) {
      // 진행률에 따라 남은 시간 추정
      final totalExpectedDistance = widget.oreum.distance?.toDouble() ?? 1000;
      final progress = _totalDistance / totalExpectedDistance;
      final remainingMinutes = (defaultTimeUp * (1 - progress)).round();
      if (remainingMinutes > 0) {
        return '약 ${remainingMinutes}분';
      }
    }

    return '-';
  }

  // 카메라 버튼
  Widget _buildCameraButton() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 200,
      child: FloatingActionButton(
        heroTag: 'camera',
        backgroundColor: Colors.white,
        onPressed: _takePhoto,
        child: const Icon(Icons.camera_alt, color: AppColors.primary),
      ),
    );
  }

  // 사진 촬영
  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
            action: SnackBarAction(
              label: '설정',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _hikingPhotos.add(File(photo.path));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 ${_hikingPhotos.length}장 저장됨'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('사진 촬영 오류: $e');
    }
  }

  // 촬영된 사진 미리보기
  Widget _buildPhotoPreview() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 150,
      child: GestureDetector(
        onTap: _showPhotoGallery,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  _hikingPhotos.last,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              if (_hikingPhotos.length > 1)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_hikingPhotos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 사진 갤러리 보기
  void _showPhotoGallery() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '촬영한 사진 (${_hikingPhotos.length}장)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _hikingPhotos.length,
                itemBuilder: (context, index) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _hikingPhotos[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _hikingPhotos.removeAt(index);
                          });
                          Navigator.pop(context);
                          if (_hikingPhotos.isNotEmpty) {
                            _showPhotoGallery();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailedStats() {
    final avgSpeed = _elapsedSeconds > 0
        ? (_totalDistance / 1000) / (_elapsedSeconds / 3600)
        : 0.0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.oreum.name} - ${_isDescending ? "하산" : "등반"} 상세',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 시간/거리
              Row(
                children: [
                  Expanded(child: _buildDetailStat('총 시간', _formatDuration(_elapsedSeconds), Icons.schedule)),
                  Expanded(child: _buildDetailStat('총 거리', '${(_totalDistance / 1000).toStringAsFixed(2)} km', Icons.straighten)),
                ],
              ),
              const SizedBox(height: 12),
              // 걸음수/칼로리
              Row(
                children: [
                  Expanded(child: _buildDetailStat('걸음수', _formatNumber(_hikingSteps), Icons.directions_walk)),
                  Expanded(child: _buildDetailStat('칼로리', '$_calculatedCalories kcal', Icons.local_fire_department)),
                ],
              ),
              const SizedBox(height: 12),
              // 고도
              Row(
                children: [
                  Expanded(child: _buildDetailStat('누적 상승', '+${_elevationGain.toStringAsFixed(0)}m', Icons.trending_up)),
                  Expanded(child: _buildDetailStat('누적 하강', '-${_elevationLoss.toStringAsFixed(0)}m', Icons.trending_down)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_maxAltitude > 0)
                    Expanded(child: _buildDetailStat('최고 고도', '${_maxAltitude.toStringAsFixed(0)}m', Icons.height)),
                  if (_minAltitude < double.infinity)
                    Expanded(child: _buildDetailStat('최저 고도', '${_minAltitude.toStringAsFixed(0)}m', Icons.height)),
                ],
              ),
              const SizedBox(height: 12),
              // 평균속도/남은거리
              Row(
                children: [
                  Expanded(child: _buildDetailStat('평균 속도', '${avgSpeed.toStringAsFixed(1)} km/h', Icons.speed)),
                  if (!_isDescending)
                    Expanded(child: _buildDetailStat('정상까지', _distanceToSummit > 1000
                        ? '${(_distanceToSummit / 1000).toStringAsFixed(1)}km'
                        : '${_distanceToSummit.toInt()}m', Icons.flag)),
                ],
              ),
              if (_isDescending) ...[
                const Divider(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('하산 기록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildDetailStat('하산 거리', '${(_descentDistance / 1000).toStringAsFixed(2)} km', Icons.straighten)),
                    Expanded(child: _buildDetailStat('하산 시간', _formatDuration(_descentSeconds), Icons.schedule)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDetailStat('하산 걸음수', _formatNumber(_descentSteps), Icons.directions_walk)),
                    Expanded(child: _buildDetailStat('하산 칼로리', '$_descentCalories kcal', Icons.local_fire_department)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: _isHiking ? _buildHikingControls() : _buildStartButton(),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    // autoStart로 진입하여 권한 확인 중일 때는 로딩만 표시
    if (_isStarting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('등반 준비 중...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.oreum.distance != null || widget.oreum.timeUp != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.oreum.distance != null) ...[
                  Icon(Icons.straighten, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${(widget.oreum.distance! / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.oreum.timeUp != null) ...[
                  Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '약 ${widget.oreum.timeUp}분',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startHiking,
            icon: const Icon(Icons.play_arrow),
            label: const Text('등반 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHikingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 스탬프 인증 버튼
        _buildStampVerifyButton(),
        const SizedBox(height: 12),
        // 일시정지/완료 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 일시정지/재개 버튼
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPaused ? _resumeHiking : _pauseHiking,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? '재개' : '일시정지'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaused ? AppColors.primary : Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 완료 버튼
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _completeHiking,
                icon: const Icon(Icons.flag),
                label: Text(_isDescending ? '하산 완료' : '완료'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStampVerifyButton() {
    final hasStamp = context.watch<StampProvider>().hasStamp(widget.oreum.id);

    return GestureDetector(
      onTap: hasStamp ? null : _verifyStamp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasStamp
                ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasStamp ? Icons.verified : Icons.verified_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              hasStamp ? '스탬프 획득 완료!' : '스탬프 인증하기',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyStamp() async {
    final stampProvider = context.read<StampProvider>();
    final result = await stampProvider.verifyAndStamp(widget.oreum);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success ? '🎉 스탬프 인증 성공!' : result.message),
          backgroundColor: result.success ? Colors.green : null,
        ),
      );
    }
  }

  // 시설물 목록 패널 (접기/펼치기)
  Widget _buildFacilityListPanel() {
    if (_currentFacilities.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      top: MediaQuery.of(context).padding.top + (_isHiking ? 160 : 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 패널 본체
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isFacilityPanelOpen ? null : 0,
            constraints: BoxConstraints(
              maxHeight: 250,
              maxWidth: _isFacilityPanelOpen ? 160 : 0,
            ),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isFacilityPanelOpen
                  ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
                  : [],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '시설물 (${_currentFacilities.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._currentFacilities.asMap().entries.map((entry) {
                    final index = entry.key;
                    final facility = entry.value;
                    final isSelected = _selectedFacility == facility;
                    return InkWell(
                      onTap: () {
                        _mapController?.setCenter(facility.location);
                        setState(() {
                          _selectedFacility = facility;
                        });
                        _buildFacilityMarkers();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.red.withOpacity(0.15) : null,
                          border: Border(
                            left: isSelected
                                ? const BorderSide(color: Colors.red, width: 3)
                                : BorderSide.none,
                            bottom: BorderSide(
                              color: index < _currentFacilities.length - 1
                                  ? AppColors.border
                                  : Colors.transparent,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFacilityIcon(facility.type),
                              size: isSelected ? 20 : 18,
                              color: isSelected ? Colors.red : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              facility.type,
                              style: TextStyle(
                                fontSize: isSelected ? 14 : 13,
                                color: isSelected ? Colors.red : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // 접기/펼치기 버튼
          GestureDetector(
            onTap: () {
              setState(() {
                _isFacilityPanelOpen = !_isFacilityPanelOpen;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6),
                ],
              ),
              child: Icon(
                _isFacilityPanelOpen ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFacilityIcon(String type) {
    switch (type) {
      case '시종점':
        return Icons.flag;
      case '정상':
        return Icons.landscape;
      case '화장실':
        return Icons.wc;
      case '쉼터':
        return Icons.chair;
      case '주차장':
        return Icons.local_parking;
      case '매점':
        return Icons.store;
      case '분기점':
        return Icons.call_split;
      case '안내판또는지도':
        return Icons.info;
      default:
        return Icons.place;
    }
  }
}

// GPS 경로를 그리는 CustomPainter
class RoutePainter extends CustomPainter {
  final List<Position> positions;
  final Color? strokeColor;
  final double? strokeWidth;

  RoutePainter({required this.positions, this.strokeColor, this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) {
      // 경로가 없으면 안내 텍스트
      final textPainter = TextPainter(
        text: TextSpan(
          text: '경로 없음',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
      );
      return;
    }

    // 경로의 경계 계산
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = math.min(minLat, pos.latitude);
      maxLat = math.max(maxLat, pos.latitude);
      minLng = math.min(minLng, pos.longitude);
      maxLng = math.max(maxLng, pos.longitude);
    }

    // 여백 추가
    final padding = 20.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;

    // 스케일 계산
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    // 0으로 나누기 방지
    if (latRange == 0 && lngRange == 0) {
      // 단일 포인트만 있는 경우
      final centerX = size.width / 2;
      final centerY = size.height / 2;

      final paint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 8, paint);
      return;
    }

    final scaleX = lngRange > 0 ? availableWidth / lngRange : 1.0;
    final scaleY = latRange > 0 ? availableHeight / latRange : 1.0;
    final scale = math.min(scaleX, scaleY);

    // 중앙 정렬을 위한 오프셋
    final scaledWidth = lngRange * scale;
    final scaledHeight = latRange * scale;
    final offsetX = padding + (availableWidth - scaledWidth) / 2;
    final offsetY = padding + (availableHeight - scaledHeight) / 2;

    // 좌표 변환 함수
    Offset toCanvas(Position pos) {
      final x = offsetX + (pos.longitude - minLng) * scale;
      final y = offsetY + (maxLat - pos.latitude) * scale; // Y축 반전
      return Offset(x, y);
    }

    // 경로 그리기
    final path = Path();
    path.moveTo(toCanvas(positions.first).dx, toCanvas(positions.first).dy);

    for (int i = 1; i < positions.length; i++) {
      final point = toCanvas(positions[i]);
      path.lineTo(point.dx, point.dy);
    }

    // 경로 선
    final pathPaint = Paint()
      ..color = strokeColor ?? AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, pathPaint);

    // 시작점 (녹색)
    final startPoint = toCanvas(positions.first);
    canvas.drawCircle(
      startPoint,
      8,
      Paint()..color = Colors.green,
    );
    canvas.drawCircle(
      startPoint,
      5,
      Paint()..color = Colors.white,
    );

    // 끝점 (빨간색)
    final endPoint = toCanvas(positions.last);
    canvas.drawCircle(
      endPoint,
      8,
      Paint()..color = Colors.red,
    );
    canvas.drawCircle(
      endPoint,
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.positions.length != positions.length;
  }
}
