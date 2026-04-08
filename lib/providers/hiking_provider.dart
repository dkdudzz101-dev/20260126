import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/oreum_model.dart';
import '../services/map_service.dart';
import '../services/background_location_service.dart';
import '../services/pedometer_service.dart';

/// 등산 상태를 앱 전체에서 관리하는 Provider.
/// HikingScreen이 dispose되어도 등산 기록이 유지됨.
class HikingProvider extends ChangeNotifier with WidgetsBindingObserver {
  final MapService _mapService = MapService();

  // 현재 등산 중인 오름
  OreumModel? _currentOreum;
  OreumModel? get currentOreum => _currentOreum;

  // 등반 상태
  bool _isHiking = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _isStarting = false;

  bool get isHiking => _isHiking;
  bool get isPaused => _isPaused;
  bool get isCompleted => _isCompleted;
  bool get isStarting => _isStarting;
  set isStarting(bool v) { _isStarting = v; notifyListeners(); }

  // 추적 데이터
  Position? _currentPosition;
  List<Position> _trackPositions = [];
  double _totalDistance = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;

  Position? get currentPosition => _currentPosition;
  List<Position> get trackPositions => _trackPositions;
  double get totalDistance => _totalDistance;
  int get elapsedSeconds => _elapsedSeconds;
  MapService get mapService => _mapService;

  // 걸음수 추적
  int _startSteps = 0;
  int _hikingSteps = 0;
  int get startSteps => _startSteps;
  int get hikingSteps => _hikingSteps;

  // 고도 추적
  double _maxAltitude = 0;
  double _minAltitude = double.infinity;
  double _elevationGain = 0;
  double _elevationLoss = 0;
  double _lastAltitude = 0;
  double _currentAltitude = 0;
  int _calculatedCalories = 0;

  double get maxAltitude => _maxAltitude;
  double get minAltitude => _minAltitude;
  double get elevationGain => _elevationGain;
  double get elevationLoss => _elevationLoss;
  double get lastAltitude => _lastAltitude;
  double get currentAltitude => _currentAltitude;
  int get calculatedCalories => _calculatedCalories;
  set calculatedCalories(int v) => _calculatedCalories = v;

  // 정상 도착 추적
  double _distanceToSummit = 0;
  bool _reachedSummit = false;
  bool _summitDialogShown = false;

  double get distanceToSummit => _distanceToSummit;
  bool get reachedSummit => _reachedSummit;
  bool get summitDialogShown => _summitDialogShown;
  set summitDialogShown(bool v) => _summitDialogShown = v;
  set reachedSummit(bool v) { _reachedSummit = v; notifyListeners(); }

  // 하산 모드
  bool _isDescending = false;
  bool _descentCompleted = false;
  bool _descentDialogShown = false;
  double _descentDistance = 0;
  int _descentSeconds = 0;
  int _descentSteps = 0;
  int _descentStartSteps = 0;
  double _descentElevationGain = 0;
  double _descentElevationLoss = 0;
  int _descentCalories = 0;
  double _ascentDistance = 0;
  int _ascentSeconds = 0;
  int _ascentSteps = 0;

  bool get isDescending => _isDescending;
  bool get descentCompleted => _descentCompleted;
  bool get descentDialogShown => _descentDialogShown;
  set descentDialogShown(bool v) => _descentDialogShown = v;
  double get descentDistance => _descentDistance;
  int get descentSeconds => _descentSeconds;
  int get descentSteps => _descentSteps;
  int get descentStartSteps => _descentStartSteps;
  double get descentElevationGain => _descentElevationGain;
  double get descentElevationLoss => _descentElevationLoss;
  int get descentCalories => _descentCalories;
  set descentCalories(int v) => _descentCalories = v;
  double get ascentDistance => _ascentDistance;
  int get ascentSeconds => _ascentSeconds;
  int get ascentSteps => _ascentSteps;

  // 사진
  // 사진은 File 타입이라 여기서는 경로만 관리
  // (실제 File 객체는 HikingScreen에서 관리)

  // PedometerService 참조 (타이머에서 사용)
  PedometerService? _pedometerService;

  // 화면에서 넘겨받은 MapService와 Timer
  MapService? _screenMapService;
  Timer? _screenTimer;

  HikingProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// HikingScreen이 dispose될 때 상태를 넘겨받음
  void syncFromScreen({
    required OreumModel oreum,
    required bool isHiking,
    required bool isPaused,
    Position? currentPosition,
    required List<Position> trackPositions,
    required double totalDistance,
    required int elapsedSeconds,
    required int startSteps,
    required int hikingSteps,
    required double maxAltitude,
    required double minAltitude,
    required double elevationGain,
    required double elevationLoss,
    required double lastAltitude,
    required double currentAltitude,
    required int calculatedCalories,
    required bool reachedSummit,
    required bool isDescending,
    required double descentDistance,
    required int descentSeconds,
    required int descentSteps,
    required int descentStartSteps,
    required double descentElevationGain,
    required double descentElevationLoss,
    required double ascentDistance,
    required int ascentSeconds,
    required int ascentSteps,
    required PedometerService pedometerService,
    required MapService mapService,
    Timer? timer,
  }) {
    _currentOreum = oreum;
    _isHiking = isHiking;
    _isPaused = isPaused;
    _currentPosition = currentPosition;
    _trackPositions = List.from(trackPositions);
    _totalDistance = totalDistance;
    _elapsedSeconds = elapsedSeconds;
    _startSteps = startSteps;
    _hikingSteps = hikingSteps;
    _maxAltitude = maxAltitude;
    _minAltitude = minAltitude;
    _elevationGain = elevationGain;
    _elevationLoss = elevationLoss;
    _lastAltitude = lastAltitude;
    _currentAltitude = currentAltitude;
    _calculatedCalories = calculatedCalories;
    _reachedSummit = reachedSummit;
    _isDescending = isDescending;
    _descentDistance = descentDistance;
    _descentSeconds = descentSeconds;
    _descentSteps = descentSteps;
    _descentStartSteps = descentStartSteps;
    _descentElevationGain = descentElevationGain;
    _descentElevationLoss = descentElevationLoss;
    _ascentDistance = ascentDistance;
    _ascentSeconds = ascentSeconds;
    _ascentSteps = ascentSteps;
    _pedometerService = pedometerService;

    // 화면의 MapService와 Timer를 이어받음
    _screenMapService = mapService;
    _screenTimer = timer;

    // 타이머가 없으면 새로 시작
    if (_screenTimer == null || !_screenTimer!.isActive) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    } else {
      // 화면 타이머를 Provider 타이머로 교체
      _screenTimer!.cancel();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    }

    // GPS 추적은 이미 mapService에서 돌고 있으므로 콜백만 변경
    // (화면의 _onPositionUpdate → Provider의 onPositionUpdate)
    mapService.stopTracking();
    mapService.startTracking(onPositionUpdate: onPositionUpdate);

    notifyListeners();
  }

  /// HikingScreen이 다시 열릴 때 Provider에서 상태 가져감
  /// Provider의 타이머/GPS 추적을 멈추고 화면에 넘김
  void syncToScreen() {
    _timer?.cancel();
    _timer = null;
    // GPS 추적은 화면이 다시 시작할 것이므로 여기서 멈춤
    if (_screenMapService != null) {
      _screenMapService!.stopTracking();
    }
    // isHiking 상태는 유지하되 Provider의 타이머만 멈춤
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _screenMapService?.stopTracking();
    _screenMapService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isHiking) saveHikingState();
    }
  }

  /// 등산 시작 (권한 획득 후 호출)
  void initializeHike({
    required OreumModel oreum,
    required PedometerService pedometerService,
    required int startSteps,
    required bool bgGranted,
  }) {
    _currentOreum = oreum;
    _pedometerService = pedometerService;
    _isStarting = false;
    _isHiking = true;
    _isPaused = false;
    _isCompleted = false;
    _trackPositions = [];
    _totalDistance = 0;
    _elapsedSeconds = 0;
    _hikingSteps = 0;
    _startSteps = startSteps;
    _maxAltitude = 0;
    _minAltitude = double.infinity;
    _elevationGain = 0;
    _elevationLoss = 0;
    _lastAltitude = 0;
    _currentAltitude = 0;
    _calculatedCalories = 0;
    _reachedSummit = false;
    _summitDialogShown = false;
    _isDescending = false;
    _descentCompleted = false;
    _descentDialogShown = false;
    _descentDistance = 0;
    _descentSeconds = 0;
    _descentSteps = 0;
    _descentStartSteps = 0;
    _descentElevationGain = 0;
    _descentElevationLoss = 0;
    _descentCalories = 0;
    _ascentDistance = 0;
    _ascentSeconds = 0;
    _ascentSteps = 0;

    // 백그라운드 서비스 시작
    if (bgGranted) {
      BackgroundLocationService.startService();
    }

    // 타이머 시작
    _updateHikingNotification();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);

    // GPS 추적 시작
    _mapService.startTracking(onPositionUpdate: onPositionUpdate);

    notifyListeners();
  }

  void _onTimerTick(Timer timer) {
    if (!_isPaused && _pedometerService != null) {
      final currentSteps = _pedometerService!.todaySteps;
      _elapsedSeconds++;
      _hikingSteps = currentSteps - _startSteps;
      if (_hikingSteps < 0) _hikingSteps = 0;

      if (_isDescending) {
        _descentSeconds++;
        _descentSteps = currentSteps - _descentStartSteps;
        if (_descentSteps < 0) _descentSteps = 0;
      }

      // 10초마다 알림 업데이트
      if (_elapsedSeconds % 10 == 0) {
        _updateHikingNotification();
      }

      notifyListeners();
    }
  }

  /// GPS 위치 업데이트 콜백
  void onPositionUpdate(Position position) {
    if (_isPaused) return;

    _currentPosition = position;

    // 이전 위치가 있으면 거리 계산
    if (_trackPositions.isNotEmpty) {
      final lastPos = _trackPositions.last;
      final distance = _mapService.calculateDistance(
        lastPos.latitude, lastPos.longitude,
        position.latitude, position.longitude,
      );
      if (_isDescending) {
        _descentDistance += distance;
      } else {
        _totalDistance += distance;
      }
    }

    // 고도 추적
    final altitude = position.altitude;
    if (altitude > 0 && altitude < 10000) {
      _currentAltitude = altitude;
      if (_trackPositions.isNotEmpty && _lastAltitude > 0) {
        final altDiff = altitude - _lastAltitude;
        if (altDiff.abs() > 2) {
          if (_isDescending) {
            if (altDiff > 0) _descentElevationGain += altDiff;
            else _descentElevationLoss += altDiff.abs();
          } else {
            if (altDiff > 0) _elevationGain += altDiff;
            else _elevationLoss += altDiff.abs();
          }
        }
      }
      if (altitude > _maxAltitude) _maxAltitude = altitude;
      if (altitude < _minAltitude) _minAltitude = altitude;
      _lastAltitude = altitude;
    }

    _trackPositions.add(position);

    // 정상 거리 계산
    if (_currentOreum?.summitLat != null && _currentOreum?.summitLng != null) {
      _distanceToSummit = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        _currentOreum!.summitLat!, _currentOreum!.summitLng!,
      );
      if (_distanceToSummit <= 100 && !_reachedSummit) {
        _reachedSummit = true;
      }
    }

    notifyListeners();
  }

  /// 일시정지
  void pauseHiking() {
    _isPaused = true;
    _mapService.stopTracking();
    notifyListeners();
  }

  /// 재개
  void resumeHiking() {
    _isPaused = false;
    _mapService.startTracking(onPositionUpdate: onPositionUpdate);
    notifyListeners();
  }

  /// 하산 시작
  void startDescent(PedometerService pedometer) {
    _isDescending = true;
    _ascentDistance = _totalDistance;
    _ascentSeconds = _elapsedSeconds;
    _ascentSteps = _hikingSteps;
    _descentStartSteps = pedometer.todaySteps;
    _descentDistance = 0;
    _descentSeconds = 0;
    _descentSteps = 0;
    _descentElevationGain = 0;
    _descentElevationLoss = 0;
    notifyListeners();
  }

  /// 등산 완료 처리 (데이터만 - UI는 화면에서 처리)
  void completeHiking() {
    _isCompleted = true;
    _timer?.cancel();
    _cancelHikingNotification();
    _mapService.stopTracking();
    BackgroundLocationService.stopService();
    _isHiking = false;
    notifyListeners();
  }

  /// 등산 상태 완전 초기화
  void resetState() {
    _isHiking = false;
    _isPaused = false;
    _isCompleted = false;
    _isStarting = false;
    _currentOreum = null;
    _trackPositions = [];
    _totalDistance = 0;
    _elapsedSeconds = 0;
    _hikingSteps = 0;
    _reachedSummit = false;
    _isDescending = false;
    clearHikingState();
    notifyListeners();
  }

  /// 위치 갱신 (권한 획득 후)
  Future<void> updateCurrentPosition() async {
    final position = await _mapService.getCurrentPosition();
    if (position != null) {
      _currentPosition = position;
      notifyListeners();
    }
  }

  // ─── 상태 저장/복원 (SharedPreferences) ───

  Future<void> saveHikingState() async {
    if (!_isHiking) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hiking_active', true);
      await prefs.setString('hiking_oreum_id', _currentOreum?.id ?? '');
      await prefs.setString('hiking_oreum_name', _currentOreum?.name ?? '');
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
      await prefs.setInt('hiking_saved_at', DateTime.now().millisecondsSinceEpoch);
      final positionData = _trackPositions.map((p) =>
        '${p.latitude},${p.longitude},${p.altitude},${p.timestamp.toIso8601String()}'
      ).toList();
      await prefs.setStringList('hiking_positions', positionData);
    } catch (e) {
      debugPrint('등산 상태 저장 실패: $e');
    }
  }

  /// SharedPreferences에서 등산 상태 복원.
  /// [oreumId] 가 null이면 아무 오름이든 복원, 아니면 해당 오름만 복원.
  Future<bool> restoreHikingState({
    String? oreumId,
    PedometerService? pedometerService,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('hiking_active') ?? false;
      final savedOreumId = prefs.getString('hiking_oreum_id') ?? '';

      if (!isActive) return false;
      if (oreumId != null && savedOreumId != oreumId) return false;

      final savedAt = prefs.getInt('hiking_saved_at') ?? 0;
      if (savedAt == 0) return false;

      final elapsed = DateTime.now().millisecondsSinceEpoch - savedAt;
      final additionalSeconds = elapsed ~/ 1000;

      _pedometerService = pedometerService;
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

      // GPS 경로 복원
      final positionData = prefs.getStringList('hiking_positions') ?? [];
      _trackPositions = [];
      for (final data in positionData) {
        final parts = data.split(',');
        if (parts.length >= 3) {
          _trackPositions.add(Position(
            latitude: double.parse(parts[0]),
            longitude: double.parse(parts[1]),
            altitude: double.parse(parts[2]),
            timestamp: parts.length >= 4 ? DateTime.parse(parts[3]) : DateTime.now(),
            accuracy: 0, altitudeAccuracy: 0, heading: 0,
            headingAccuracy: 0, speed: 0, speedAccuracy: 0,
          ));
        }
      }

      // 걸음수 서비스 재시작
      if (pedometerService != null) {
        if (!pedometerService.isInitialized) {
          await pedometerService.initialize();
        }
        _startSteps = pedometerService.todaySteps - _hikingSteps;
      }

      // 타이머 재시작
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);

      // GPS 추적 재시작
      _mapService.startTracking(onPositionUpdate: onPositionUpdate);

      notifyListeners();
      debugPrint('등산 상태 복원 완료 (Provider)');
      return true;
    } catch (e) {
      debugPrint('등산 상태 복원 실패: $e');
      await clearHikingState();
      return false;
    }
  }

  Future<void> clearHikingState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('hiking_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ─── 알림 ───

  void _updateHikingNotification() {
    if (_currentOreum == null) return;
    final totalDist = _isDescending ? (_ascentDistance + _descentDistance) : _totalDistance;
    final distStr = totalDist >= 1000
        ? '${(totalDist / 1000).toStringAsFixed(1)}km'
        : '${totalDist.toStringAsFixed(0)}m';
    final totalSecs = _elapsedSeconds + (_isDescending ? _descentSeconds : 0);
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    final timeStr = h > 0
        ? '${h}시간 ${m.toString().padLeft(2, '0')}분'
        : '${m}분 ${s.toString().padLeft(2, '0')}초';

    final notifications = FlutterLocalNotificationsPlugin();
    notifications.show(
      888,
      '🥾 ${_currentOreum!.name} 등산 중',
      '$distStr · $timeStr · ${_hikingSteps}걸음',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jeju_oreum_location', '등산 추적',
          channelDescription: '등산 중 실시간 정보',
          importance: Importance.low, priority: Priority.low,
          ongoing: true, autoCancel: false, showWhen: false,
        ),
        iOS: DarwinNotificationDetails(presentAlert: false, presentBadge: false),
      ),
    );
  }

  void _cancelHikingNotification() {
    FlutterLocalNotificationsPlugin().cancel(888);
  }
}
