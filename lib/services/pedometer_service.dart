import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService extends ChangeNotifier {
  int _todaySteps = 0;
  double _todayDistance = 0.0; // km
  int _baseSteps = 0; // 자정 기준 걸음수
  String _lastResetDate = '';

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianSubscription;

  bool _isWalking = false;
  bool _isInitialized = false;

  // 평균 보폭 (cm) - 사용자 설정 가능하게 할 수도 있음
  static const double averageStepLength = 65.0; // cm

  int get todaySteps => _todaySteps;
  double get todayDistance => _todayDistance;
  bool get isWalking => _isWalking;
  bool get isInitialized => _isInitialized;

  // 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 권한 요청
    final permissionGranted = await _requestPermission();
    if (!permissionGranted) {
      debugPrint('걸음수 권한이 거부되었습니다');
      return;
    }

    // 저장된 데이터 로드
    await _loadSavedData();

    // 날짜 체크 및 리셋
    await _checkDateAndReset();

    // 걸음수 스트림 시작
    _startListening();

    _isInitialized = true;
    notifyListeners();
  }

  // 권한 요청
  Future<bool> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  // 저장된 데이터 로드
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _baseSteps = prefs.getInt('pedometer_base_steps') ?? 0;
    _lastResetDate = prefs.getString('pedometer_last_reset_date') ?? '';
    _todaySteps = prefs.getInt('pedometer_today_steps') ?? 0;
    _todayDistance = _calculateDistance(_todaySteps);
  }

  // 날짜 체크 및 리셋
  Future<void> _checkDateAndReset() async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (_lastResetDate != today) {
      // 새로운 날이면 리셋
      _todaySteps = 0;
      _todayDistance = 0.0;
      _baseSteps = 0; // 실제 걸음수가 들어오면 업데이트됨
      _lastResetDate = today;
      await _saveData();
    }
  }

  // 걸음수 리스닝 시작
  void _startListening() {
    // 걸음수 스트림
    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
    );

    // 걷기 상태 스트림
    _pedestrianSubscription = Pedometer.pedestrianStatusStream.listen(
      _onPedestrianStatus,
      onError: _onPedestrianStatusError,
    );
  }

  // 걸음수 이벤트 처리
  void _onStepCount(StepCount event) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // 날짜가 바뀌었는지 확인
    if (_lastResetDate != today) {
      _baseSteps = event.steps;
      _lastResetDate = today;
      _todaySteps = 0;
    } else if (_baseSteps == 0) {
      // 첫 번째 이벤트인 경우 기준점 설정
      _baseSteps = event.steps - _todaySteps;
    }

    _todaySteps = event.steps - _baseSteps;
    if (_todaySteps < 0) _todaySteps = 0;

    _todayDistance = _calculateDistance(_todaySteps);

    await _saveData();
    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint('걸음수 에러: $error');
  }

  // 걷기 상태 이벤트 처리
  void _onPedestrianStatus(PedestrianStatus event) {
    _isWalking = event.status == 'walking';
    notifyListeners();
  }

  void _onPedestrianStatusError(error) {
    debugPrint('걷기 상태 에러: $error');
  }

  // 거리 계산 (km)
  double _calculateDistance(int steps) {
    return (steps * averageStepLength) / 100000; // cm -> km
  }

  // 데이터 저장
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pedometer_base_steps', _baseSteps);
    await prefs.setString('pedometer_last_reset_date', _lastResetDate);
    await prefs.setInt('pedometer_today_steps', _todaySteps);
  }

  // 걸음수 수동 리셋 (테스트용)
  Future<void> resetSteps() async {
    _todaySteps = 0;
    _todayDistance = 0.0;
    _baseSteps = 0;
    _lastResetDate = DateTime.now().toIso8601String().split('T')[0];
    await _saveData();
    notifyListeners();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _pedestrianSubscription?.cancel();
    super.dispose();
  }
}
