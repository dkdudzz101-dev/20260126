import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../services/stamp_service.dart';
import '../../services/map_service.dart';
import '../../services/pedometer_service.dart';
import '../../services/hiking_route_service.dart';
import '../../utils/calorie_calculator.dart';
import '../../utils/login_guard.dart';
import '../../providers/stamp_provider.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with WidgetsBindingObserver {
  final StampService _stampService = StampService();
  final HikingRouteService _hikingRouteService = HikingRouteService();

  bool _isActive = false;
  bool _isPaused = false;

  Position? _currentPosition;
  List<Position> _trackPositions = [];
  double _totalDistance = 0;
  int _elapsedSeconds = 0;
  Timer? _timer;

  int _startSteps = 0;
  int _exerciseSteps = 0;

  double _maxAltitude = 0;
  double _minAltitude = double.infinity;
  double _elevationGain = 0;
  double _elevationLoss = 0;
  double _lastAltitude = 0;

  int _calculatedCalories = 0;

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startExercise() async {
    if (!LoginGuard.check(context, message: '운동을 시작하려면 로그인이 필요합니다.\n로그인 하시겠습니까?')) return;

    final fgGranted = await MapService.ensureLocationPermission(context);
    if (!fgGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('운동을 시작하려면 위치 권한이 필요합니다')),
        );
      }
      return;
    }

    // 걸음수 권한
    final actStatus = await Permission.activityRecognition.request();
    if (actStatus.isGranted && mounted) {
      final pedometer = context.read<PedometerService>();
      await pedometer.initialize();
      _startSteps = pedometer.todaySteps;
    }

    // 현재 위치
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져올 수 없습니다')),
        );
      }
      return;
    }

    setState(() {
      _isActive = true;
      _isPaused = false;
      _totalDistance = 0;
      _elapsedSeconds = 0;
      _trackPositions = [];
      _exerciseSteps = 0;
      _maxAltitude = _currentPosition!.altitude;
      _minAltitude = _currentPosition!.altitude;
      _lastAltitude = _currentPosition!.altitude;
      _elevationGain = 0;
      _elevationLoss = 0;
      _calculatedCalories = 0;
    });

    _startTimer();
    _startTracking();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
          _updateCalories();
          _updateSteps();
        });
      }
    });
  }

  void _updateSteps() {
    try {
      final pedometer = context.read<PedometerService>();
      _exerciseSteps = pedometer.todaySteps - _startSteps;
      if (_exerciseSteps < 0) _exerciseSteps = 0;
    } catch (_) {}
  }

  void _updateCalories() {
    _calculatedCalories = CalorieCalculator.calculateHikingCalories(
      distanceKm: _totalDistance / 1000,
      durationMinutes: _elapsedSeconds ~/ 60,
      elevationGainM: _elevationGain,
      elevationLossM: _elevationLoss,
    );
  }

  void _startTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (_isPaused || !_isActive) return;

      setState(() {
        if (_trackPositions.isNotEmpty) {
          final lastPos = _trackPositions.last;
          final dist = Geolocator.distanceBetween(
            lastPos.latitude, lastPos.longitude,
            position.latitude, position.longitude,
          );
          if (dist < 100) {
            _totalDistance += dist;
          }
        }

        // 고도
        final alt = position.altitude;
        if (alt > _maxAltitude) _maxAltitude = alt;
        if (alt < _minAltitude) _minAltitude = alt;
        final altDiff = alt - _lastAltitude;
        if (altDiff > 1) _elevationGain += altDiff;
        if (altDiff < -1) _elevationLoss += altDiff.abs();
        _lastAltitude = alt;

        _currentPosition = position;
        _trackPositions.add(position);
      });
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopExercise() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('운동 종료'),
        content: const Text('운동을 종료하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('종료')),
        ],
      ),
    );

    if (confirm != true) return;

    _timer?.cancel();
    _positionStream?.cancel();

    setState(() {
      _isActive = false;
      _isPaused = false;
    });

    _updateSteps();
    _updateCalories();

    await _saveExercise();
  }

  Future<void> _saveExercise() async {
    final memoController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fitness_center, color: AppColors.primary),
            SizedBox(width: 8),
            Text('운동 완료!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('거리', _formatDistance(_totalDistance)),
            _buildResultRow('시간', _formatDuration(_elapsedSeconds ~/ 60)),
            _buildResultRow('걸음수', _formatNumber(_exerciseSteps)),
            _buildResultRow('칼로리', '${_calculatedCalories}kcal'),
            const SizedBox(height: 12),
            TextField(
              controller: memoController,
              maxLength: 50,
              decoration: const InputDecoration(
                hintText: '메모 (선택)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('저장 안함'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      try {
        final avgSpeed = _elapsedSeconds > 0
            ? (_totalDistance / 1000) / (_elapsedSeconds / 3600)
            : 0.0;

        await _stampService.recordExerciseLog(
          distanceWalked: _totalDistance,
          timeTaken: _elapsedSeconds ~/ 60,
          steps: _exerciseSteps,
          avgSpeed: avgSpeed,
          calories: _calculatedCalories,
          elevationGain: _elevationGain,
          elevationLoss: _elevationLoss,
          maxAltitude: _maxAltitude,
          minAltitude: _minAltitude == double.infinity ? null : _minAltitude,
          memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
        );

        // 경로 저장
        if (_trackPositions.isNotEmpty) {
          await _hikingRouteService.saveRoute(
            oreumId: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
            positions: _trackPositions,
          );
        }

        if (mounted) {
          context.read<StampProvider>().loadStamps();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('운동 기록이 저장되었습니다'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        debugPrint('에러: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장에 실패했습니다.')),
          );
        }
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isActive ? const Color(0xFF1A1A1A) : Colors.white,
      appBar: AppBar(
        title: const Text('운동'),
        backgroundColor: _isActive ? const Color(0xFF1A1A1A) : null,
        foregroundColor: _isActive ? Colors.white : null,
      ),
      body: _isActive ? _buildActiveView() : _buildReadyView(),
    );
  }

  Widget _buildReadyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.directions_walk, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('일반 운동', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '오름 선택 없이 걷기/달리기를\n자유롭게 기록하세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startExercise,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('운동 시작', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 시간 (큰 글씨)
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  if (_isPaused)
                    const Text('일시정지', style: TextStyle(color: Colors.orange, fontSize: 14)),
                  const SizedBox(height: 40),
                  // 주요 스탯
                  Row(
                    children: [
                      Expanded(child: _buildStat('거리', _formatDistance(_totalDistance), 'km')),
                      Container(width: 1, height: 50, color: Colors.white24),
                      Expanded(child: _buildStat('걸음수', _formatNumber(_exerciseSteps), '걸음')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildStat('칼로리', '$_calculatedCalories', 'kcal')),
                      Container(width: 1, height: 50, color: Colors.white24),
                      Expanded(child: _buildStat('고도', '+${_elevationGain.toStringAsFixed(0)}', 'm')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 하단 컨트롤
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 일시정지/재개
                GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isPaused ? Colors.green : Colors.orange,
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                // 종료
                GestureDetector(
                  onTap: _stopExercise,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Icon(Icons.stop, color: Colors.white, size: 36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return (meters / 1000).toStringAsFixed(2);
    return '${meters.toInt()}m';
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) return '${minutes ~/ 60}시간 ${minutes % 60}분';
    return '$minutes분';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
