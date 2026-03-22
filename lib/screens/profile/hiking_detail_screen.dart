import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../providers/stamp_provider.dart';
import '../../services/hiking_route_service.dart';
import '../../services/stamp_service.dart';
import '../../services/share_service.dart';
import '../../widgets/hiking_share_card.dart';

class _KmPoint {
  final int km;
  final LatLng latLng;
  _KmPoint({required this.km, required this.latLng});
}

class HikingDetailScreen extends StatefulWidget {
  final StampModel stamp;

  const HikingDetailScreen({super.key, required this.stamp});

  @override
  State<HikingDetailScreen> createState() => _HikingDetailScreenState();
}

class _HikingDetailScreenState extends State<HikingDetailScreen> {
  final HikingRouteService _routeService = HikingRouteService();
  final ShareService _shareService = ShareService();
  List<Map<String, dynamic>>? _routeData;
  List<String>? _photoUrls;
  bool _isLoading = true;
  KakaoMapController? _mapController;

  // 지도 확장 & km 선택
  bool _isMapExpanded = false;
  List<_KmPoint> _kmPoints = [];
  int? _selectedKm;
  double _mapRatio = 0.4; // 지도 높이 비율 (0.2 ~ 0.8)

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    try {
      Map<String, dynamic>? data;

      // record_type에 따라 적절한 방법으로 경로 조회
      if (widget.stamp.isHikingLog) {
        data = await _routeService.getRouteByLogId(widget.stamp.id);
      } else {
        data = await _routeService.getRouteWithPhotos(widget.stamp.id);
      }

      debugPrint('경로 조회 결과: data=${data != null}, route_data=${data?['route_data'] != null}, points=${(data?['route_data'] as List?)?.length ?? 0}');

      if (mounted) {
        setState(() {
          if (data != null) {
            if (data['route_data'] != null) {
              _routeData = List<Map<String, dynamic>>.from(data['route_data']);
            }
            if (data['photo_urls'] != null) {
              _photoUrls = List<String>.from(data['photo_urls']);
            }
          }
          _isLoading = false;
        });
        if (_routeData != null) _calculateKmPoints();
      }
    } catch (e) {
      debugPrint('경로 로드 실패: $e (stamp.id=${widget.stamp.id}, type=${widget.stamp.recordType})');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateKmPoints() {
    if (_routeData == null || _routeData!.isEmpty) return;
    final pts = _routeData!
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();

    final kms = <_KmPoint>[];
    double cum = 0;
    int next = 1;
    for (int i = 1; i < pts.length; i++) {
      cum += _haversine(pts[i - 1], pts[i]);
      if (cum >= next * 1000) {
        kms.add(_KmPoint(km: next, latLng: pts[i]));
        next++;
      }
    }
    setState(() => _kmPoints = kms);
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  Future<void> _shareRecord() async {
    final stamp = widget.stamp;
    final dateStr = '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, '0')}.${stamp.stampedAt.day.toString().padLeft(2, '0')}';

    String? selectedPhotoUrl = (_photoUrls != null && _photoUrls!.isNotEmpty) ? _photoUrls!.first : null;
    File? localPhoto; // 카메라/앨범에서 선택한 로컬 사진
    final toggles = {
      'date': true,
      'distance': true,
      'time': true,
      'steps': true,
      'calories': stamp.calories != null,
      'altitude': stamp.elevationGain != null,
    };
    bool isSharing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            // 선택된 항목들로 정보 문자열 생성
            final infoParts = <String>[];
            if (toggles['distance']!) infoParts.add(_formatDistance(stamp.distanceWalked));
            if (toggles['time']!) infoParts.add(_formatDuration(stamp.timeTaken));
            if (toggles['steps']!) infoParts.add(_formatSteps(stamp.steps));
            if (toggles['calories']! && stamp.calories != null) infoParts.add('${stamp.calories}kcal');
            if (toggles['altitude']! && stamp.elevationGain != null) infoParts.add('+${stamp.elevationGain!.toStringAsFixed(0)}m');
            if (toggles['date']!) infoParts.add(dateStr);

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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // 미리보기
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 280,
                              child: (localPhoto != null || selectedPhotoUrl != null)
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (localPhoto != null)
                                          Image.file(localPhoto!, fit: BoxFit.cover)
                                        else
                                          Image.network(selectedPhotoUrl!, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image, size: 48),
                                            ),
                                          ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withValues(alpha: 0.15),
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.7),
                                              ],
                                              stops: const [0.0, 0.3, 1.0],
                                            ),
                                          ),
                                        ),
                                        // 워터마크
                                        Positioned(
                                          top: 12, right: 12,
                                          child: Text('JEJUOREUM', style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            fontSize: 12, fontWeight: FontWeight.w700,
                                            letterSpacing: 2.0,
                                          )),
                                        ),
                                        Positioned(
                                          bottom: 0, left: 0, right: 0,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(stamp.oreumName, style: const TextStyle(
                                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                                                )),
                                                if (infoParts.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(infoParts.join('  |  '), style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.85), fontSize: 11,
                                                  )),
                                                ],
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
                                          Text(stamp.oreumName, style: TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600],
                                          )),
                                          if (infoParts.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(infoParts.join('  |  '), style: TextStyle(
                                              fontSize: 11, color: Colors.grey[500],
                                            )),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 카메라/앨범/기존사진 선택 버튼
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                                    if (picked != null) {
                                      setModalState(() {
                                        localPhoto = File(picked.path);
                                        selectedPhotoUrl = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('카메라'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                                    if (picked != null) {
                                      setModalState(() {
                                        localPhoto = File(picked.path);
                                        selectedPhotoUrl = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.photo_library, size: 18),
                                  label: const Text('앨범'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              if (localPhoto != null && (_photoUrls != null && _photoUrls!.isNotEmpty)) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setModalState(() {
                                        localPhoto = null;
                                        selectedPhotoUrl = _photoUrls!.first;
                                      });
                                    },
                                    icon: const Icon(Icons.restore, size: 18),
                                    label: const Text('원래 사진'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // 기존 사진 썸네일 (여러 장일 때)
                          if (localPhoto == null && _photoUrls != null && _photoUrls!.length > 1) ...[
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _photoUrls!.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final isSelected = selectedPhotoUrl == _photoUrls![index];
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() => selectedPhotoUrl = _photoUrls![index]);
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
                                        child: Image.network(_photoUrls![index], fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // 토글 옵션
                          _buildToggle('날짜', Icons.calendar_today, toggles['date']!, (v) {
                            setModalState(() => toggles['date'] = v);
                          }),
                          _buildToggle('거리', Icons.straighten, toggles['distance']!, (v) {
                            setModalState(() => toggles['distance'] = v);
                          }),
                          _buildToggle('시간', Icons.schedule, toggles['time']!, (v) {
                            setModalState(() => toggles['time'] = v);
                          }),
                          _buildToggle('걸음수', Icons.directions_walk, toggles['steps']!, (v) {
                            setModalState(() => toggles['steps'] = v);
                          }),
                          if (stamp.calories != null)
                            _buildToggle('칼로리', Icons.local_fire_department, toggles['calories']!, (v) {
                              setModalState(() => toggles['calories'] = v);
                            }),
                          if (stamp.elevationGain != null)
                            _buildToggle('고도', Icons.trending_up, toggles['altitude']!, (v) {
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
                            // 경로 좌표 변환
                            List<Map<String, double>>? routePts;
                            if (_routeData != null && _routeData!.length >= 2) {
                              routePts = _routeData!.map((p) => {
                                'lat': (p['lat'] as num).toDouble(),
                                'lng': (p['lng'] as num).toDouble(),
                              }).toList();
                            }
                            final shareCard = HikingShareCard(
                              oreumName: stamp.oreumName,
                              date: toggles['date']! ? dateStr : null,
                              distanceKm: toggles['distance']! ? (stamp.distanceWalked ?? 0) / 1000 : null,
                              durationMinutes: toggles['time']! ? (stamp.timeTaken ?? 0) : null,
                              steps: toggles['steps']! ? (stamp.steps ?? 0) : null,
                              photoUrl: localPhoto == null ? selectedPhotoUrl : null,
                              localPhotoFile: localPhoto,
                              calories: toggles['calories']! ? stamp.calories : null,
                              elevationGain: toggles['altitude']! ? stamp.elevationGain : null,
                              routePoints: routePts,
                            );
                            final imagePath = await _shareService.captureWidget(widget: shareCard);

                            if (!mounted) return;
                            Navigator.pop(sheetContext);

                            await _shareService.shareImage(
                              imagePath: imagePath,
                              oreumName: stamp.oreumName,
                              text: '${stamp.oreumName} 등반 완료!\n#JEJUOREUM #등산',
                            );
                          } catch (e) {
                            debugPrint('에러: $e');
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

  Widget _buildToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stamp = widget.stamp;
    final title = stamp.memo != null && stamp.memo!.isNotEmpty
        ? '${stamp.oreumName} - ${stamp.memo}'
        : stamp.oreumName;

    return Scaffold(
      appBar: _isMapExpanded
          ? null
          : AppBar(
              title: Text(title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareRecord,
                  tooltip: '공유',
                ),
              ],
            ),
      body: _isMapExpanded
          ? _buildFullscreenMap()
          : LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = constraints.maxHeight * _mapRatio;
                return Column(
                  children: [
                    SizedBox(height: mapHeight, child: _buildMap()),
                    // 드래그 핸들
                    GestureDetector(
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _mapRatio += details.delta.dy / constraints.maxHeight;
                          _mapRatio = _mapRatio.clamp(0.2, 0.8);
                        });
                      },
                      child: Container(
                        height: 20,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _buildStats()),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMap() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final kakaoMap = _buildKakaoMap();

    return Stack(
      children: [
        kakaoMap,
        // 경로 없음 안내
        if (_routeData == null || _routeData!.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '경로 데이터가 없습니다',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        // km 선택 칩 (하단)
        if (_kmPoints.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildKmSelector(),
          ),
        // 전체화면 버튼 (우상단)
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() => _isMapExpanded = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKakaoMap() {
    final polylines = <Polyline>[];
    final markers = <Marker>{};
    final customOverlays = <CustomOverlay>[];
    LatLng? center;

    if (_routeData != null && _routeData!.isNotEmpty) {
      final points = _routeData!
          .where((p) => p['lat'] != null && p['lng'] != null)
          .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
          .toList();

      if (points.isNotEmpty) {
        center = points[points.length ~/ 2];

        polylines.add(Polyline(
          polylineId: 'route',
          points: points,
          strokeColor: AppColors.primary,
          strokeWidth: 4,
        ));

        // 출발 마커 (초록)
        markers.add(Marker(
          markerId: 'start',
          latLng: points.first,
          markerImageSrc:
              'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="28" height="36" viewBox="0 0 28 36"><path d="M14 0C6.268 0 0 6.268 0 14c0 9.333 14 22 14 22s14-12.667 14-22C28 6.268 21.732 0 14 0z" fill="%234CAF50" stroke="white" stroke-width="2"/><circle cx="14" cy="14" r="5" fill="white"/></svg>',
          width: 28,
          height: 36,
        ));

        // 도착 마커 (빨강)
        markers.add(Marker(
          markerId: 'end',
          latLng: points.last,
          markerImageSrc:
              'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="28" height="36" viewBox="0 0 28 36"><path d="M14 0C6.268 0 0 6.268 0 14c0 9.333 14 22 14 22s14-12.667 14-22C28 6.268 21.732 0 14 0z" fill="%23F44336" stroke="white" stroke-width="2"/><circle cx="14" cy="14" r="5" fill="white"/></svg>',
          width: 28,
          height: 36,
        ));
      }
    }

    // km 배지 CustomOverlay
    for (final km in _kmPoints) {
      final isSelected = _selectedKm == km.km;
      final bg = isSelected ? '%234CAF50' : '%23ffffff';
      final fg = isSelected ? '%23ffffff' : '%234CAF50';
      customOverlays.add(CustomOverlay(
        customOverlayId: 'km_${km.km}',
        latLng: km.latLng,
        content:
            '<div style="background:$bg;border:2px solid %234CAF50;border-radius:12px;padding:2px 7px;font-size:11px;font-weight:700;color:$fg;white-space:nowrap;">${km.km}km</div>',
        yAnchor: 1.0,
      ));
    }

    // 기본 center: 경로 중간점 → 오름 좌표 → 제주 중심
    final defaultCenter = LatLng(widget.stamp.lat, widget.stamp.lng);

    return KakaoMap(
      onMapCreated: (controller) {
        _mapController = controller;
        if (_routeData != null && _routeData!.isNotEmpty) {
          _fitBoundsToRoute(_routeData!
              .where((p) => p['lat'] != null && p['lng'] != null)
              .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
              .toList());
        } else if (center != null) {
          controller.setCenter(center);
        }
      },
      center: center ?? defaultCenter,
      currentLevel: 4,
      polylines: polylines,
      markers: markers.toList(),
      customOverlays: customOverlays,
    );
  }

  // 전체화면 지도 (AppBar 없이, 뒤로가기+km선택 오버레이)
  Widget _buildFullscreenMap() {
    return SafeArea(
      child: Stack(
        children: [
          _buildKakaoMap(),
          // 닫기 버튼
          Positioned(
            top: 12,
            left: 12,
            child: GestureDetector(
              onTap: () => setState(() {
                _isMapExpanded = false;
                _selectedKm = null;
                // 전체 경로 다시 맞춤
                if (_routeData != null && _routeData!.isNotEmpty) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _fitBoundsToRoute(_routeData!
                        .where((p) => p['lat'] != null && p['lng'] != null)
                        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                        .toList());
                  });
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 22),
              ),
            ),
          ),
          // 전체 경로 버튼 (km 선택 중일 때)
          if (_selectedKm != null)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedKm = null);
                  if (_routeData != null) {
                    _fitBoundsToRoute(_routeData!
                        .where((p) => p['lat'] != null && p['lng'] != null)
                        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                        .toList());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('전체 경로', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ),
          // km 선택 칩 (하단)
          if (_kmPoints.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildKmSelector(),
            ),
        ],
      ),
    );
  }

  Widget _buildKmSelector() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('구간 선택', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 전체 버튼
                _buildKmChip(
                  label: '전체',
                  isSelected: _selectedKm == null,
                  onTap: () {
                    setState(() => _selectedKm = null);
                    if (_routeData != null) {
                      _fitBoundsToRoute(_routeData!
                          .where((p) => p['lat'] != null && p['lng'] != null)
                          .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                          .toList());
                    }
                  },
                ),
                const SizedBox(width: 6),
                ..._kmPoints.map((km) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildKmChip(
                        label: '${km.km}km',
                        isSelected: _selectedKm == km.km,
                        onTap: () {
                          setState(() => _selectedKm = km.km);
                          _mapController?.setCenter(km.latLng);
                          _mapController?.setLevel(2); // 해당 지점 확대
                        },
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKmChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _fitBoundsToRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // 여백 10%
    final latPad = (maxLat - minLat) * 0.15;
    final lngPad = (maxLng - minLng) * 0.15;
    minLat -= latPad; maxLat += latPad;
    minLng -= lngPad; maxLng += lngPad;

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final maxDiff = (maxLat - minLat) > (maxLng - minLng)
        ? (maxLat - minLat)
        : (maxLng - minLng);

    int zoom;
    if (maxDiff < 0.001) { zoom = 1; }
    else if (maxDiff < 0.002) { zoom = 2; }
    else if (maxDiff < 0.004) { zoom = 3; }
    else if (maxDiff < 0.008) { zoom = 4; }
    else if (maxDiff < 0.015) { zoom = 5; }
    else if (maxDiff < 0.03) { zoom = 6; }
    else { zoom = 7; }

    _mapController!.setCenter(LatLng(centerLat, centerLng));
    _mapController!.setLevel(zoom);
  }

  Widget _buildStats() {
    final stamp = widget.stamp;
    final dateStr = '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, '0')}.${stamp.stampedAt.day.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 + 기록 타입 배지
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stamp.isStamp
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stamp.isStamp ? '완등' : '등산 기록',
                  style: TextStyle(
                    color: stamp.isStamp ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 메모
          GestureDetector(
            onTap: () => _showEditMemoDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.stamp.memo != null && widget.stamp.memo!.isNotEmpty
                          ? widget.stamp.memo!
                          : '메모를 추가하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.stamp.memo != null && widget.stamp.memo!.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 통계
          Row(
            children: [
              Expanded(child: _buildMainStatCard('이동 거리', _formatDistance(stamp.distanceWalked), Icons.straighten)),
              const SizedBox(width: 12),
              Expanded(child: _buildMainStatCard('소요 시간', _formatDuration(stamp.timeTaken), Icons.schedule)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMainStatCard('걸음수', _formatSteps(stamp.steps), Icons.directions_walk)),
              const SizedBox(width: 12),
              Expanded(child: _buildMainStatCard('평균 속도', stamp.avgSpeed != null ? '${stamp.avgSpeed!.toStringAsFixed(1)} km/h' : '-', Icons.speed)),
            ],
          ),

          // 고도 정보
          if (stamp.elevationGain != null || stamp.maxAltitude != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terrain, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('고도 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (stamp.maxAltitude != null)
                        Expanded(child: _buildMiniStat('최고 고도', '${stamp.maxAltitude!.toStringAsFixed(0)}m')),
                      if (stamp.minAltitude != null)
                        Expanded(child: _buildMiniStat('최저 고도', '${stamp.minAltitude!.toStringAsFixed(0)}m')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (stamp.elevationGain != null)
                        Expanded(child: _buildMiniStat('누적 상승', '+${stamp.elevationGain!.toStringAsFixed(0)}m')),
                      if (stamp.elevationLoss != null)
                        Expanded(child: _buildMiniStat('누적 하강', '-${stamp.elevationLoss!.toStringAsFixed(0)}m')),
                    ],
                  ),
                  if (stamp.calories != null) ...[
                    const SizedBox(height: 8),
                    _buildMiniStat('소모 칼로리', '${stamp.calories} kcal'),
                  ],
                ],
              ),
            ),
          ],

          // 등반 사진
          if (_photoUrls != null && _photoUrls!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_library, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '등반 사진 (${_photoUrls!.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoUrls!.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _showPhotoDetail(_photoUrls![index]),
                        child: Container(
                          width: 100,
                          margin: EdgeInsets.only(right: index < _photoUrls!.length - 1 ? 8 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _photoUrls![index],
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 경로 없음 안내
          if (_routeData == null || _routeData!.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textSecondary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'GPS 경로 데이터가 없습니다.\n새로운 등반부터 경로가 저장됩니다.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditMemoDialog() {
    final controller = TextEditingController(text: widget.stamp.memo ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('메모 수정'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(
            hintText: '이 등반에 대한 메모를 남겨보세요',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final memo = controller.text.trim();
              Navigator.pop(ctx);

              try {
                final stampService = StampService();
                await stampService.updateLatestRecordMemo(
                  oreumId: widget.stamp.oreumId,
                  memo: memo,
                );
                setState(() {
                  widget.stamp.memo = memo.isEmpty ? null : memo;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('메모가 저장되었습니다')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('메모 저장에 실패했습니다')),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  void _showPhotoDetail(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double? distance) {
    if (distance == null) return '-';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '-';
    if (minutes >= 60) {
      return '${minutes ~/ 60}시간 ${minutes % 60}분';
    }
    return '$minutes분';
  }

  String _formatSteps(int? steps) {
    if (steps == null) return '-';
    return steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}
