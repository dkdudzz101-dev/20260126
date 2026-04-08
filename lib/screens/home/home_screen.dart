import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../providers/oreum_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../services/banner_service.dart';
import '../../services/weather_service.dart';
import '../../services/oreum_service.dart';
import '../../services/sunrise_service.dart';
import '../../services/map_service.dart';
import '../../models/oreum_model.dart';
import '../../services/ranking_service.dart';
import '../oreum/oreum_detail_screen.dart';
import '../oreum/oreum_search_screen.dart';
import '../ranking/ranking_screen.dart';
import '../exercise/exercise_screen.dart';
import '../menu/notification_screen.dart';
import '../menu/notice_screen.dart';
import '../../services/notification_service.dart';
import '../../services/notice_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const HomeScreen({super.key, this.onMenuTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BannerService _bannerService = BannerService();
  final WeatherService _weatherService = WeatherService();
  final NotificationService _notificationService = NotificationService();
  final PageController _bannerController = PageController();

  List<String> _bannerImages = [];
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  // 읽지 않은 알림 수
  int _unreadNotificationCount = 0;

  // 오늘의 추천 오름
  OreumModel? _recommendedOreum;
  String _recommendReason = '';
  WeatherData? _currentWeather;

  // 가까운 오름
  List<Map<String, dynamic>> _nearbyOreums = [];
  Position? _currentPosition;

  // 일출/일몰
  SunTimes? _sunTimes;

  // 랭킹
  List<RankingUser> _topRankers = [];

  // 최신 공지
  Map<String, dynamic>? _latestNotice;
  bool _noticeVisible = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) {
        setState(() => _unreadNotificationCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadLatestNotice() async {
    try {
      final notice = await NoticeService().getLatestNotice();
      if (mounted && notice != null) {
        setState(() {
          _latestNotice = notice;
          _noticeVisible = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    // 알림 수 로드
    _loadNotificationCount();

    // 최신 공지 로드
    _loadLatestNotice();

    // 배너 로드
    final banners = await _bannerService.getBannerImages();
    if (mounted) {
      setState(() {
        _bannerImages = banners;
      });
      _startBannerTimer();
    }

    // 일출/일몰 계산
    if (mounted) {
      setState(() {
        _sunTimes = SunriseSunsetService.getTodaySunTimes();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 오름 데이터 로드 완료까지 대기
      await context.read<OreumProvider>().loadOreums();
      await context.read<StampProvider>().loadStamps();

      // 날씨 로드 후 추천 오름 계산
      await _loadWeatherAndRecommendation();
      // 위치 기반 가까운 오름 (권한이 이미 있을 때만, 요청 안 함)
      await _loadNearbyOreumsIfPermitted();
      // 랭킹 로드
      _loadTopRankers();
    });
  }

  Future<void> _loadTopRankers() async {
    final rankers = await RankingService.getRanking(limit: 3);
    if (mounted) setState(() => _topRankers = rankers);
  }

  Future<void> _loadWeatherAndRecommendation() async {
    final weather = await _weatherService.getCurrentWeather(
      lat: _currentPosition?.latitude,
      lng: _currentPosition?.longitude,
    );
    if (!mounted) return;

    setState(() {
      _currentWeather = weather;
    });

    final oreums = context.read<OreumProvider>().allOreums;
    if (oreums.isEmpty) {
      debugPrint('오름 데이터가 비어있음');
      return;
    }

    // 날씨에 따른 테마 선택
    String recommendedTheme;
    String reason;

    if (weather != null) {
      final temp = weather.temperature;
      final condition = weather.condition.toLowerCase();

      if (condition.contains('비') || condition.contains('rain')) {
        recommendedTheme = 'family';
        reason = '비 오는 날씨, 짧고 쉬운 코스 추천';
      } else if (condition.contains('흐') || condition.contains('cloud')) {
        recommendedTheme = 'forest';
        reason = '흐린 날씨, 숲속 힐링 코스 추천';
      } else if (temp >= 25) {
        recommendedTheme = 'forest';
        reason = '더운 날씨, 시원한 숲속 코스 추천';
      } else if (temp >= 10 && temp <= 24) {
        recommendedTheme = 'scenic';
        reason = '등산하기 좋은 날씨, 전망 좋은 오름 추천';
      } else {
        recommendedTheme = 'famous';
        reason = '오늘의 추천 오름';
      }
    } else {
      recommendedTheme = 'famous';
      reason = '오늘의 추천 오름';
    }

    // 해당 테마 오름 중 랜덤 선택
    final random = Random();
    OreumModel selectedOreum;

    try {
      // 테마별 오름 가져오기
      final oreumService = OreumService();
      final themeOreums = await oreumService.getOreumsByTheme(recommendedTheme);

      if (themeOreums.isNotEmpty) {
        selectedOreum = themeOreums[random.nextInt(themeOreums.length)];
      } else {
        // 테마 오름이 없으면 전체에서 선택
        selectedOreum = oreums[random.nextInt(oreums.length)];
      }
    } catch (e) {
      debugPrint('테마 오름 로드 실패: $e');
      // 실패시 전체에서 선택
      selectedOreum = oreums[random.nextInt(oreums.length)];
    }

    if (mounted) {
      setState(() {
        _recommendedOreum = selectedOreum;
        _recommendReason = reason;
      });
    }
  }

  /// 권한이 이미 있을 때만 가까운 오름 로드 (자동 호출용, 절대 권한 요청 안 함)
  Future<void> _loadNearbyOreumsIfPermitted() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    await _loadNearbyOreums();
  }

  Future<void> _loadNearbyOreums() async {
    try {

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (!mounted) return;

      _currentPosition = position;

      final oreums = context.read<OreumProvider>().allOreums;
      if (oreums.isEmpty) return;

      // 각 오름까지 거리 계산 (정상 좌표 기준)
      List<Map<String, dynamic>> oreumsWithDistance = [];
      for (final oreum in oreums) {
        final lat = oreum.summitLat ?? oreum.startLat;
        final lng = oreum.summitLng ?? oreum.startLng;
        if (lat != null && lng != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );
          oreumsWithDistance.add({
            'oreum': oreum,
            'distance': distance,
          });
        }
      }

      // 거리순 정렬
      oreumsWithDistance.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

      if (mounted) {
        setState(() {
          _nearbyOreums = oreumsWithDistance.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('위치 로드 오류: $e');
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_bannerImages.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _bannerController.hasClients) {
          final nextPage = (_currentBannerIndex + 1) % _bannerImages.length;
          _bannerController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final headerHeight = 70.0;
    final bannerHeight = screenHeight * 0.75;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 상단 헤더바 (올레패스 스타일)
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: statusBarHeight),
            child: Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 왼쪽: 앱 로고/이름
                  const Text(
                    '제주오름',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  // 오른쪽: 액션 버튼들
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationScreen()),
                              );
                              _loadNotificationCount();
                            },
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black87),
                        onPressed: widget.onMenuTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 배너 + 바텀시트
          Expanded(
            child: Stack(
              children: [
                // 배너
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: bannerHeight,
                  child: _buildBanner(bannerHeight),
                ),
                // 드래그 가능한 바텀 시트
                DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.3,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, -5),
                          ),
                        ],
                      ),
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              // 드래그 핸들
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_latestNotice != null && _noticeVisible)
                                _buildLatestNoticeBanner(),
                              _buildRecommendedOreum(),
                              const SizedBox(height: 20),
                              _buildNearbyOreums(),
                              const SizedBox(height: 20),
                              _buildThemeSectionSimple(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(double height) {
    return Stack(
      children: [
        // 배너 이미지
        SizedBox(
          height: height,
          width: double.infinity,
          child: _bannerImages.isEmpty
              ? Container(
                  color: AppColors.primary.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                )
              : PageView.builder(
                  controller: _bannerController,
                  itemCount: _bannerImages.length,
                  onPageChanged: (index) => setState(() => _currentBannerIndex = index),
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: _bannerImages[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.primary.withOpacity(0.3),
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('배너 로드 실패: $url');
                        return Container(
                          color: AppColors.primary,
                          child: const Center(
                            child: Icon(Icons.landscape, size: 64, color: Colors.white),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),

        // 페이지 인디케이터 (올레 스타일 - 동그란 점)
        if (_bannerImages.length > 1)
          Positioned(
            bottom: 220,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _bannerImages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentBannerIndex == index
                        ? const Color(0xFF2196F3)  // 파란색 (선택됨)
                        : Colors.white.withOpacity(0.5),  // 반투명 흰색
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSunTimesWidget() {
    if (_sunTimes == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final isSunrise = now.hour < 12;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isSunrise
              ? [const Color(0xFFFF9E80), const Color(0xFFFFAB40)]
              : [const Color(0xFF5C6BC0), const Color(0xFF7E57C2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 일출
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.wb_sunny,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '일출',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _sunTimes!.sunriseFormatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 구분선
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withOpacity(0.3),
          ),
          // 일몰
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '일몰',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _sunTimes!.sunsetFormatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.nightlight_round,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestNoticeBanner() {
    final notice = _latestNotice!;
    final title = notice['title'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoticeScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _noticeVisible = false),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedOreum() {
    if (_recommendedOreum == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('추천 오름 로딩중...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('오늘의 추천', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (_currentWeather != null)
                Text(
                  '${_currentWeather!.temperature.toInt()}°C ${_currentWeather!.condition}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              if (_sunTimes != null) ...[
                const SizedBox(width: 6),
                Text(
                  '일출 ${_sunTimes!.sunriseFormatted} 일몰 ${_sunTimes!.sunsetFormatted}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OreumDetailScreen(oreum: _recommendedOreum!),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recommendedOreum!.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildInfoChip(_recommendedOreum!.difficulty ?? '보통'),
                          const SizedBox(width: 8),
                          Text(
                            '${(_recommendedOreum!.timeUp ?? 0) + (_recommendedOreum!.timeDown ?? 0)}분',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(_recommendedOreum!.distance ?? 0).toStringAsFixed(1)}km',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (_currentPosition != null &&
                              (_recommendedOreum!.summitLat ?? _recommendedOreum!.startLat) != null &&
                              (_recommendedOreum!.summitLng ?? _recommendedOreum!.startLng) != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.location_on, size: 12, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              _formatDistance(Geolocator.distanceBetween(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                                _recommendedOreum!.summitLat ?? _recommendedOreum!.startLat!,
                                _recommendedOreum!.summitLng ?? _recommendedOreum!.startLng!,
                              )),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String text) {
    Color chipColor;
    switch (text) {
      case '쉬움':
        chipColor = const Color(0xFF4CAF50);
        break;
      case '보통':
        chipColor = const Color(0xFFFF9800);
        break;
      case '어려움':
        chipColor = const Color(0xFFF44336);
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildExerciseQuickStart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExerciseScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_walk, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '일반 운동 시작',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '오름 선택 없이 자유롭게 걷기/달리기',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyOreums() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('가까운 오름', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        if (_nearbyOreums.isEmpty)
          GestureDetector(
            onTap: () async {
              final granted = await MapService.ensureLocationPermission(context);
              if (granted && mounted) {
                await _loadNearbyOreums();
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 20, color: Colors.grey[500]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '위치 권한을 허용하면 가까운 오름을 확인할 수 있습니다',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                ],
              ),
            ),
          )
        else
          ...(_nearbyOreums.map((item) {
            final oreum = item['oreum'] as OreumModel;
            final distance = item['distance'] as double;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OreumDetailScreen(oreum: oreum),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            oreum.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(oreum.difficulty ?? '보통'),
                        ],
                      ),
                    ),
                    Text(
                      _formatDistance(distance),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList()),
      ],
    );
  }

  Widget _buildMyProgress() {
    return Consumer2<StampProvider, OreumProvider>(
      builder: (context, stampProvider, oreumProvider, _) {
        final stampCount = stampProvider.stampCount;
        final totalOreums = oreumProvider.allOreums.length;
        final progress = totalOreums > 0 ? stampCount / totalOreums : 0.0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('내 오름 현황', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation(Colors.white), minHeight: 8),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$stampCount / $totalOreums 오름', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  Text('${totalOreums - stampCount}개 남음', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniRanking() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RankingScreen())),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.leaderboard, color: AppColors.primary, size: 22),
                    SizedBox(width: 6),
                    Text('오름 랭킹', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                    )),
                  ],
                ),
                Text('전체보기', style: TextStyle(
                  fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _topRankers.map((user) {
                final initial = user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?';
                final medalColors = [const Color(0xFFD4A853), const Color(0xFFA8A8A8), const Color(0xFFB87333)];
                final medalColor = user.rank <= 3 ? medalColors[user.rank - 1] : AppColors.textHint;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: medalColor,
                        ),
                        child: Center(
                          child: Text('${user.rank}', style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white,
                          )),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: medalColor, width: 1.5),
                        ),
                        child: ClipOval(
                          child: user.profileImage != null
                              ? Image.network(user.profileImage!, fit: BoxFit.cover,
                                  width: 32, height: 32,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(initial, style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12,
                                    )),
                                  ),
                                )
                              : Center(
                                  child: Text(initial, style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12,
                                  )),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(user.nickname, style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                        )),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Lv.${user.level}',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSectionSimple() {
    final themes = [
      {'name': '일출명소', 'icon': Icons.wb_sunny, 'color': const Color(0xFFFF7043)},
      {'name': '일몰명소', 'icon': Icons.nights_stay, 'color': const Color(0xFF5C6BC0)},
      {'name': '대표명소', 'icon': Icons.star, 'color': const Color(0xFFFFB300)},
      {'name': '전망좋은', 'icon': Icons.landscape, 'color': const Color(0xFF2196F3)},
      {'name': '숲속힐링', 'icon': Icons.forest, 'color': const Color(0xFF4CAF50)},
      {'name': '가족추천', 'icon': Icons.family_restroom, 'color': const Color(0xFF9C27B0)},
      {'name': '강아지동반', 'icon': Icons.pets, 'color': const Color(0xFF795548)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('테마별 오름', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              final themeName = theme['name'] as String;
              final themeIcon = theme['icon'] as IconData;
              final themeColor = theme['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _navigateToThemeList(themeName),
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(themeIcon, color: themeColor, size: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          themeName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToThemeList(String themeName) async {
    final oreumProvider = context.read<OreumProvider>();

    // 테마 이름을 테마 키로 매핑
    String themeKey;
    switch (themeName) {
      case '일출명소':
        themeKey = 'sunrise';
        break;
      case '일몰명소':
        themeKey = 'sunset';
        break;
      case '대표명소':
        themeKey = 'famous';
        break;
      case '전망좋은':
        themeKey = 'scenic';
        break;
      case '숲속힐링':
        themeKey = 'forest';
        break;
      case '가족추천':
        themeKey = 'family';
        break;
      case '강아지동반':
        themeKey = 'pet';
        break;
      case '계절명소':
        themeKey = 'seasonal';
        break;
      default:
        themeKey = '';
    }

    // 테마별 오름 필터 적용 (oreum_themes 매핑 테이블 사용)
    await oreumProvider.filterByTheme(themeKey);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OreumSearchScreen(initialTitle: '$themeName 오름'),
      ),
    );
  }

  Widget _buildThemeSection() {
    final themes = [
      {'name': '대표명소', 'icon': Icons.star, 'color': Colors.amber},
      {'name': '전망좋은', 'icon': Icons.landscape, 'color': Colors.blue},
      {'name': '숲속힐링', 'icon': Icons.forest, 'color': Colors.green},
      {'name': '가족추천', 'icon': Icons.family_restroom, 'color': Colors.purple},
      {'name': '계절명소', 'icon': Icons.eco, 'color': Colors.orange},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('테마별 오름', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final t = themes[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t['name']} 오름 준비중'))),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: (t['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(t['icon'] as IconData, color: t['color'] as Color, size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(t['name'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySection() {
    return Consumer<OreumProvider>(
      builder: (context, provider, _) {
        final categories = [
          {'name': '쉬움', 'count': provider.allOreums.where((o) => o.difficulty == '쉬움').length, 'color': const Color(0xFF4CAF50)},
          {'name': '보통', 'count': provider.allOreums.where((o) => o.difficulty == '보통').length, 'color': const Color(0xFFFF9800)},
          {'name': '어려움', 'count': provider.allOreums.where((o) => o.difficulty == '어려움').length, 'color': const Color(0xFFF44336)},
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('난이도별 오름', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: categories.map((c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: c != categories.last ? 8 : 0),
                    child: GestureDetector(
                      onTap: () {
                        provider.filterByDifficulty(c['name'] as String);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OreumSearchScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: (c['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (c['color'] as Color).withOpacity(0.3)),
                        ),
                        child: Column(children: [
                          Text(c['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c['color'] as Color)),
                          const SizedBox(height: 2),
                          Text('${c['count']}개', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatNumber(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
