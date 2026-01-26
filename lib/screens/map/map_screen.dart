import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../providers/oreum_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/oreum_model.dart';
import '../../services/map_service.dart';
import '../../services/weather_service.dart';
import '../../services/trail_service.dart';
import '../oreum/oreum_detail_screen.dart';
import '../oreum/oreum_search_screen.dart';
import '../hiking/hiking_screen.dart';

class MapScreen extends StatefulWidget {
  final OreumModel? initialOreum;

  const MapScreen({super.key, this.initialOreum});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  KakaoMapController? _mapController;
  final MapService _mapService = MapService();
  final WeatherService _weatherService = WeatherService();
  final TrailService _trailService = TrailService();

  // 제주도 중심 좌표 (한라산 정상 기준)
  static final LatLng _jejuCenter = LatLng(33.3617, 126.5292);

  OreumModel? _selectedOreum;
  Clusterer? _oreumClusterer;
  Set<Marker> _facilityMarkers = {}; // 시설물 마커
  bool _showTrail = false;
  Set<Polyline> _trailPolylines = {};
  bool _isLoadingTrail = false;
  bool _showOnlyBookmarked = false;

  // 시설물 팝업용
  FacilityPoint? _selectedFacility;
  List<FacilityPoint> _currentFacilities = [];

  // 날씨 데이터
  WeatherData? _weatherData;

  // 현재 위치 커스텀 오버레이
  LatLng? _currentLocation;
  Set<CustomOverlay> _userLocationOverlay = {};

  @override
  void initState() {
    super.initState();
    // 지도 로드 전에 미리 위치 가져오기 시작
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _mapService.dispose();
    super.dispose();
  }

  void _onMapCreated(KakaoMapController controller) {
    _mapController = controller;
    _loadOreumMarkers();

    // 내 위치 자동 로드
    _loadCurrentLocation();

    // initialOreum이 있으면 해당 오름 선택 및 등산로 표시
    if (widget.initialOreum != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _selectOreumAndShowTrail(widget.initialOreum!);
      });
    }
  }

  Future<void> _loadCurrentLocation() async {
    final position = await _mapService.getCurrentPosition();
    if (position != null && mounted) {
      final userLatLng = LatLng(position.latitude, position.longitude);
      _updateUserLocationOverlay(userLatLng);
    }
  }

  void _updateUserLocationOverlay(LatLng userLatLng) {
    setState(() {
      _currentLocation = userLatLng;
      _userLocationOverlay = {
        CustomOverlay(
          customOverlayId: 'user_location',
          latLng: userLatLng,
          content: '<div style="width:30px;height:42px;position:relative;"><div style="width:30px;height:30px;background:linear-gradient(135deg,#ff6b6b,#e53935);border:3px solid white;border-radius:50% 50% 50% 0;transform:rotate(-45deg);box-shadow:0 3px 8px rgba(0,0,0,0.4);"></div><div style="position:absolute;top:8px;left:8px;width:14px;height:14px;background:white;border-radius:50%;"></div></div>',
          xAnchor: 0.5,
          yAnchor: 0.5,
          zIndex: 100,
        ),
      };
    });
  }

  Future<void> _selectOreumAndShowTrail(OreumModel oreum) async {
    setState(() {
      _selectedOreum = oreum;
    });

    // 지도 중심 이동 (정상 좌표 사용)
    final lat = oreum.summitLat ?? oreum.startLat;
    final lng = oreum.summitLng ?? oreum.startLng;
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.setCenter(LatLng(lat, lng));
      _mapController!.setLevel(4);
    }

    // 등산로 표시
    await _loadAndShowTrail(oreum);
  }

  Future<void> _loadOreumMarkers() async {
    final oreumProvider = context.read<OreumProvider>();
    await oreumProvider.loadOreums();
    _updateClusterer();
  }

  void _updateClusterer() {
    final oreumProvider = context.read<OreumProvider>();
    final oreums = _showOnlyBookmarked
        ? oreumProvider.getBookmarkedOreums()
        : oreumProvider.oreums;

    final markers = <Marker>[];

    for (final oreum in oreums) {
      // 정상 좌표 사용 (없으면 시작점 좌표 fallback)
      final lat = oreum.summitLat ?? oreum.startLat;
      final lng = oreum.summitLng ?? oreum.startLng;
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: oreum.id,
            latLng: LatLng(lat, lng),
          ),
        );
      }
    }

    setState(() {
      _oreumClusterer = Clusterer(
        markers: markers,
        gridSize: 60,
        minLevel: 8,
        averageCenter: true,
        minClusterSize: 2,
        styles: [
          // 2~9개
          ClustererStyle(
            width: 34,
            height: 34,
            background: const Color(0xFF3B82F6),
            borderRadius: 17,
            color: Colors.white,
            textAlign: 'center',
            lineHeight: 34,
          ),
          // 10~29개
          ClustererStyle(
            width: 40,
            height: 40,
            background: const Color(0xFF3B82F6),
            borderRadius: 20,
            color: Colors.white,
            textAlign: 'center',
            lineHeight: 40,
          ),
          // 30개 이상
          ClustererStyle(
            width: 48,
            height: 48,
            background: const Color(0xFF3B82F6),
            borderRadius: 24,
            color: Colors.white,
            textAlign: 'center',
            lineHeight: 48,
          ),
        ],
        calculator: [10, 30],
      );
    });
  }

  void _toggleBookmarkFilter() {
    // 로그인 체크
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _showOnlyBookmarked = !_showOnlyBookmarked;
    });
    _updateClusterer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_showOnlyBookmarked ? '찜한 오름만 표시합니다' : '모든 오름을 표시합니다'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('로그인 필요'),
          content: const Text('찜 기능을 사용하려면 로그인이 필요합니다.\n로그인 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('로그인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _findNearestOreum() async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final position = await _mapService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 위치를 가져올 수 없습니다')),
          );
        }
        return;
      }

      final oreumProvider = context.read<OreumProvider>();
      final oreums = oreumProvider.oreums;

      OreumModel? nearestOreum;
      double minDistance = double.infinity;

      for (final oreum in oreums) {
        // 정상 좌표 기준으로 거리 계산
        final lat = oreum.summitLat ?? oreum.startLat;
        final lng = oreum.summitLng ?? oreum.startLng;
        if (lat != null && lng != null) {
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          );
          if (distance < minDistance) {
            minDistance = distance;
            nearestOreum = oreum;
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      if (nearestOreum != null) {
        // 지도 이동 및 오름 선택 (정상 좌표)
        final nearestLat = nearestOreum.summitLat ?? nearestOreum.startLat;
        final nearestLng = nearestOreum.summitLng ?? nearestOreum.startLng;
        _mapController?.setCenter(
          LatLng(nearestLat!, nearestLng!),
        );
        setState(() {
          _selectedOreum = nearestOreum;
        });

        final distanceText = minDistance < 1000
            ? '${minDistance.toInt()}m'
            : '${(minDistance / 1000).toStringAsFixed(1)}km';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('가장 가까운 오름: ${nearestOreum.name} ($distanceText)'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주변에 오름을 찾을 수 없습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  // 클러스터 탭 이벤트 핸들러
  void _onClusterTap(LatLng position, int zoomLevel, List<Marker> clusterMarkers) {
    // 클러스터 클릭 시 줌인
    if (_mapController != null) {
      _mapController!.setCenter(position);
      // 현재 줌 레벨보다 2단계 확대
      final newLevel = (zoomLevel - 2).clamp(1, 14);
      _mapController!.setLevel(newLevel);
    }
  }

  void _onMarkerTap(String markerId, LatLng position, int zoomLevel) {
    // 시설물 마커인 경우 (지도 이동 없이 마커만 강조)
    if (markerId.startsWith('facility_')) {
      // facility_0_sel, facility_0_def 등에서 인덱스 추출
      String indexStr = markerId.replaceFirst('facility_', '');
      indexStr = indexStr.replaceAll('_sel', '').replaceAll('_def', '');
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

    // 시설물 팝업 닫기
    if (_selectedFacility != null) {
      setState(() {
        _selectedFacility = null;
      });
      _buildFacilityMarkers();
    }

    // 오름 마커인 경우
    final oreumProvider = context.read<OreumProvider>();
    final oreum = oreumProvider.oreums.firstWhere(
      (o) => o.id == markerId,
      orElse: () => OreumModel(id: '', name: ''),
    );

    if (oreum.id.isNotEmpty) {
      setState(() {
        _selectedOreum = oreum;
      });

      // 등산로 보기 상태일 때 해당 오름의 등산로로 변경
      if (_showTrail) {
        _loadAndShowTrail(oreum);
      }
    }
  }

  // 지도 탭 - 가장 가까운 오름 선택
  void _onMapTap(LatLng position) {
    // 시설물 팝업 닫기
    if (_selectedFacility != null) {
      setState(() {
        _selectedFacility = null;
      });
      _buildFacilityMarkers();
      return;
    }

    final oreumProvider = context.read<OreumProvider>();
    final oreums = _showOnlyBookmarked
        ? oreumProvider.getBookmarkedOreums()
        : oreumProvider.oreums;

    if (oreums.isEmpty) return;

    OreumModel? nearestOreum;
    double minDistance = double.infinity;

    for (final oreum in oreums) {
      // 정상 좌표 기준으로 거리 계산
      final lat = oreum.summitLat ?? oreum.startLat;
      final lng = oreum.summitLng ?? oreum.startLng;
      if (lat != null && lng != null) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestOreum = oreum;
        }
      }
    }

    // 1km 이내의 오름만 선택 (너무 멀면 무시)
    if (nearestOreum != null && minDistance < 1000) {
      setState(() {
        _selectedOreum = nearestOreum;
      });
    }
  }

  Future<void> _moveToCurrentLocation() async {
    final position = await _mapService.getCurrentPosition();
    if (position != null && _mapController != null) {
      final userLatLng = LatLng(position.latitude, position.longitude);
      _mapController!.setCenter(userLatLng);
      _updateUserLocationOverlay(userLatLng);
    }
  }

  void _openNavigation() {
    if (_selectedOreum == null) return;

    _mapService.openKakaoMapNavigation(
      destLat: _selectedOreum!.startLat ?? 0,
      destLng: _selectedOreum!.startLng ?? 0,
      destName: _selectedOreum!.name,
    );
  }

  Future<void> _startHiking(OreumModel oreum) async {
    // 현재 위치 확인
    final position = await _mapService.getCurrentPosition();

    if (position == null) {
      // 위치를 가져올 수 없으면 바로 등반 시작
      _navigateToHiking(oreum);
      return;
    }

    if (oreum.startLat == null || oreum.startLng == null) {
      _navigateToHiking(oreum);
      return;
    }

    // 입구까지 거리 계산
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      oreum.startLat!,
      oreum.startLng!,
    );

    if (distance <= 200) {
      // 200m 이내면 바로 등반 시작
      _navigateToHiking(oreum);
    } else {
      // 200m 밖이면 팝업 표시
      final distanceText = distance < 1000
          ? '${distance.toInt()}m'
          : '${(distance / 1000).toStringAsFixed(1)}km';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('입구에서 멀리 있습니다'),
          content: Text(
            '현재 위치가 ${oreum.name} 입구에서 $distanceText 떨어져 있습니다.\n\n입구로 이동하거나 현재 위치에서 시작할 수 있습니다.',
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToHiking(oreum);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('현재 위치에서 시작'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _mapService.openKakaoMapNavigation(
                      destLat: oreum.startLat!,
                      destLng: oreum.startLng!,
                      destName: '${oreum.name} 입구',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('네비 실행'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  void _navigateToHiking(OreumModel oreum) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HikingScreen(oreum: oreum),
      ),
    );
  }

  void _toggleTrailView() {
    if (_selectedOreum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 오름을 선택해주세요')),
      );
      return;
    }

    if (_showTrail) {
      // 등산로 숨기기
      setState(() {
        _showTrail = false;
        _trailPolylines = {};
        _facilityMarkers = {};
        _selectedFacility = null;
        _currentFacilities = [];
      });
    } else {
      // 등산로 로드 및 표시
      _loadAndShowTrail(_selectedOreum!);
    }
  }

  // 시설물 마커 이미지 (SVG data URL)
  String _getFacilityMarkerImage(String type, bool isSelected) {
    final color = isSelected ? '%23FF6B35' : '%232D9B4E'; // URL encoded #
    final size = isSelected ? 32 : 28;

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
        'fill="$color" stroke="white" stroke-width="2"/>'
        '<text x="${size/2}" y="${size*0.5}" text-anchor="middle" fill="white" '
        'font-size="${size*0.35}" font-weight="bold" font-family="Arial">$symbol</text>'
        '</svg>';
  }

  Future<void> _loadAndShowTrail(OreumModel oreum) async {
    if (_isLoadingTrail) return;

    setState(() {
      _isLoadingTrail = true;
      _selectedFacility = null;
    });

    try {
      final trailData = await _trailService.loadTrailDataFromSupabase(oreum.id);

      if (!mounted) return;

      if (trailData != null && trailData.trailPoints.isNotEmpty) {
        // '기타' 제외한 시설물만 필터링
        final facilitiesToShow = trailData.facilities
            .where((f) => f.type != '기타')
            .toList();

        // 등산로 폴리라인 생성 (세그먼트별로 분리)
        final polylines = <Polyline>{};
        if (trailData.trailSegments.isNotEmpty) {
          for (int i = 0; i < trailData.trailSegments.length; i++) {
            final segment = trailData.trailSegments[i];
            if (segment.length >= 2) {
              polylines.add(
                Polyline(
                  polylineId: 'trail_${oreum.id}_$i',
                  points: segment,
                  strokeColor: AppColors.primary,
                  strokeWidth: 4,
                ),
              );
            }
          }
        } else {
          polylines.add(
            Polyline(
              polylineId: 'trail_${oreum.id}',
              points: trailData.trailPoints,
              strokeColor: AppColors.primary,
              strokeWidth: 4,
            ),
          );
        }

        setState(() {
          _showTrail = true;
          _trailPolylines = polylines;
          _currentFacilities = facilitiesToShow;
          _isLoadingTrail = false;
        });

        // 시설물 마커 생성
        _buildFacilityMarkers();

        // fitBounds로 등산로 전체가 보이도록 확대
        _fitBoundsToTrail(trailData.trailPoints);
      } else {
        setState(() {
          _isLoadingTrail = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등산로 데이터가 없습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTrail = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등산로 로드 실패: $e')),
        );
      }
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
      final size = isSelected ? 32 : 28;

      markers.add(
        Marker(
          markerId: 'facility_${i}_${isSelected ? 'sel' : 'def'}',
          latLng: facility.location,
          width: size,
          height: size + 10,
          markerImageSrc: _getFacilityMarkerImage(facility.type, isSelected),
        ),
      );
    }

    setState(() {
      _facilityMarkers = markers;
    });
  }

  void _fitBoundsToTrail(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    // 경계 계산
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // 여백 추가 (경계의 10% 확장 - 등산로가 화면에 꽉 차도록)
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    // 중심점 계산 (바텀 시트가 화면 약 45%를 차지하므로, 중심을 위로 조정)
    final latRange = maxLat - minLat;
    final centerLat = (minLat + maxLat) / 2 + (latRange * 0.2); // 위로 20% 이동
    final centerLng = (minLng + maxLng) / 2;

    // 적절한 줌 레벨 계산 (경계 크기에 따라)
    // 카카오맵: 숫자가 클수록 더 넓은 영역 표시 (줌 아웃)
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    int zoomLevel;
    if (maxDiff < 0.001) {
      zoomLevel = 1;  // 매우 좁은 범위 (더 확대)
    } else if (maxDiff < 0.002) {
      zoomLevel = 2;
    } else if (maxDiff < 0.004) {
      zoomLevel = 3;
    } else if (maxDiff < 0.008) {
      zoomLevel = 4;
    } else if (maxDiff < 0.015) {
      zoomLevel = 5;
    } else if (maxDiff < 0.03) {
      zoomLevel = 6;
    } else {
      zoomLevel = 7;
    }

    // 중심 이동 및 줌 레벨 설정
    _mapController!.setCenter(LatLng(centerLat, centerLng));
    _mapController!.setLevel(zoomLevel);
  }

  Future<void> _showWeatherDialog() async {
    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 날씨 데이터 가져오기
    final weather = await _weatherService.getJejuWeather();

    if (!mounted) return;
    Navigator.pop(context); // 로딩 닫기

    if (weather == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날씨 정보를 가져올 수 없습니다')),
      );
      return;
    }

    setState(() {
      _weatherData = weather;
    });

    final hikingCondition = WeatherService.getHikingCondition(weather);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            Row(
              children: [
                Text(
                  weather.weatherIcon,
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.location} 날씨',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${weather.temperature.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 상세 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeatherItem('체감', '${weather.feelsLike.toStringAsFixed(1)}°'),
                  _buildWeatherItem('습도', '${weather.humidity}%'),
                  _buildWeatherItem('바람', '${weather.windSpeed.toStringAsFixed(1)}m/s'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 등산 적합도
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(hikingCondition.color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(hikingCondition.color).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hikingCondition.level == 'good'
                        ? Icons.check_circle
                        : hikingCondition.level == 'caution'
                            ? Icons.warning
                            : hikingCondition.level == 'bad'
                                ? Icons.cancel
                                : Icons.info,
                    color: Color(hikingCondition.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '등산 적합도',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(hikingCondition.color),
                          ),
                        ),
                        Text(
                          hikingCondition.message,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 닫기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 카카오 지도
          GestureDetector(
            onTap: () {
              if (_selectedFacility != null) {
                setState(() {
                  _selectedFacility = null;
                });
                _buildFacilityMarkers();
              }
            },
            child: KakaoMap(
              onMapCreated: _onMapCreated,
              center: _jejuCenter,
              currentLevel: 9,
              markers: _facilityMarkers.toList(),
              customOverlays: _userLocationOverlay.toList(),
              clusterer: _oreumClusterer,
              polylines: _trailPolylines.toList(),
              onMarkerTap: _onMarkerTap,
              onMapTap: _onMapTap,
              onMarkerClustererTap: _onClusterTap,
            ),
          ),
          // 상단 바
          _buildTopBar(),
          // 우측 버튼들
          _buildSideButtons(),
          // 내 위치 버튼
          _buildMyLocationButton(),
          // 바텀 시트 (오름 정보)
          _buildBottomSheet(),
          // 시설물 목록 패널 (등산로 보기 시)
          if (_showTrail && _currentFacilities.isNotEmpty) _buildFacilityListPanel(),
        ],
      ),
    );
  }

  // 시설물 목록 패널
  Widget _buildFacilityListPanel() {
    // _currentFacilities는 이미 '기타' 제외됨
    if (_currentFacilities.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      top: MediaQuery.of(context).padding.top + 80,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
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
              // 시설물 목록 ('기타' 제외)
              ..._currentFacilities.asMap().entries.map((entry) {
                final index = entry.key;
                final facility = entry.value;
                final isSelected = _selectedFacility == facility;
                return InkWell(
                  onTap: () {
                    // 목록에서 클릭할 때만 지도 이동
                    _mapController?.setCenter(facility.location);
                    setState(() {
                      _selectedFacility = facility;
                    });
                    // 마커 색상 업데이트
                    _buildFacilityMarkers();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                      border: Border(
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
                          size: 18,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          facility.type,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OreumSearchScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text(
                          '오름 검색',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ],
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

  Widget _buildSideButtons() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 80,
      child: Column(
        children: [
          _buildMapButton(
            icon: Icons.cloud_outlined,
            label: '날씨',
            onTap: _showWeatherDialog,
          ),
          const SizedBox(height: 8),
          _buildMapButton(
            icon: _showOnlyBookmarked ? Icons.bookmark : Icons.bookmark_outline,
            label: '찜',
            isActive: _showOnlyBookmarked,
            onTap: _toggleBookmarkFilter,
          ),
          const SizedBox(height: 8),
          _buildMapButton(
            icon: _showTrail ? Icons.route : Icons.route_outlined,
            label: '등산로',
            isActive: _showTrail,
            onTap: _toggleTrailView,
          ),
          const SizedBox(height: 8),
          _buildMapButton(
            icon: Icons.near_me,
            label: '가까운',
            onTap: _findNearestOreum,
          ),
        ],
      ),
    );
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 260,
      child: GestureDetector(
        onTap: _moveToCurrentLocation,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location,
            color: _currentLocation != null ? AppColors.primary : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: _selectedOreum != null ? 0.45 : 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                // 드래그 핸들
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 오름 정보 카드
                if (_selectedOreum != null)
                  _buildOreumInfoCard(_selectedOreum!)
                else
                  _buildDefaultContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultContent() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '지도에서 오름을 선택해주세요',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOreumInfoCard(OreumModel oreum) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 썸네일 (스탬프 이미지)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface,
                  image: oreum.stampUrl != null
                      ? DecorationImage(
                          image: NetworkImage(oreum.stampUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: oreum.stampUrl == null
                    ? const Icon(Icons.terrain, color: AppColors.textHint)
                    : null,
              ),
              const SizedBox(width: 16),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            oreum.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 찜 버튼
                        Consumer2<OreumProvider, AuthProvider>(
                          builder: (context, oreumProvider, authProvider, _) {
                            final isBookmarked = oreumProvider.isBookmarked(oreum.id);
                            return IconButton(
                              icon: Icon(
                                isBookmarked ? Icons.favorite : Icons.favorite_border,
                                color: isBookmarked ? Colors.red : AppColors.textSecondary,
                              ),
                              onPressed: () async {
                                if (!authProvider.isLoggedIn) {
                                  _showLoginRequiredDialog();
                                  return;
                                }
                                await oreumProvider.toggleBookmark(oreum);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    if (oreum.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        oreum.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 상세 정보
          Row(
            children: [
              if (oreum.difficulty != null)
                _buildInfoChip(Icons.star_outline, oreum.difficulty!),
              if (oreum.timeUp != null) ...[
                const SizedBox(width: 12),
                _buildInfoChip(Icons.schedule, '${oreum.timeUp}분'),
              ],
              if (oreum.distance != null) ...[
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.straighten,
                  '${oreum.distance!.toStringAsFixed(2)}km',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleTrailView,
                  icon: const Icon(Icons.visibility),
                  label: const Text('등산로 보기'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OreumDetailScreen(oreum: oreum),
                      ),
                    ).then((_) {
                      // 상세화면에서 돌아오면 클러스터 새로고침
                      if (mounted) {
                        _updateClusterer();
                      }
                    });
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('상세보기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openNavigation,
                  icon: const Icon(Icons.navigation),
                  label: const Text('길안내'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startHiking(oreum),
                  icon: const Icon(Icons.hiking),
                  label: const Text('등반 시작'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // 시설물 타입별 아이콘
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
      default:
        return Icons.place;
    }
  }
}
