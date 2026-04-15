import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/stamp_provider.dart';
import '../../services/hiking_route_service.dart';
import '../../services/stamp_service.dart';
import 'image_edit_screen.dart';

class HikingDetailScreen extends StatefulWidget {
  final StampModel stamp;
  final bool autoShare;

  const HikingDetailScreen({super.key, required this.stamp, this.autoShare = false});

  @override
  State<HikingDetailScreen> createState() => _HikingDetailScreenState();
}

class _HikingDetailScreenState extends State<HikingDetailScreen> {
  final HikingRouteService _routeService = HikingRouteService();
  List<Map<String, dynamic>>? _routeData;
  List<String>? _photoUrls;
  bool _isLoading = true;
  KakaoMapController? _mapController;

  // 지도 캡처용 키
  final GlobalKey _mapCaptureKey = GlobalKey();

  bool _isMapExpanded = false;
  bool _isSharing = false;
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
        // autoShare 모드: 로드 완료 후 자동으로 꾸미기 시트 열기
        if (widget.autoShare) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _shareRecord();
          });
        }
      }
    } catch (e) {
      debugPrint('경로 로드 실패: $e (stamp.id=${widget.stamp.id}, type=${widget.stamp.recordType})');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareRecord() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final stamp = widget.stamp;
    final dateStr = '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, "0")}.${stamp.stampedAt.day.toString().padLeft(2, "0")}';

    List<Map<String, double>>? routePts;
    if (_routeData != null && _routeData!.length >= 2) {
      routePts = _routeData!.map((p) => {
        'lat': (p['lat'] as num).toDouble(),
        'lng': (p['lng'] as num).toDouble(),
      }).toList();
    }

    // 경로 숨기고 지도만 캡처 (배경으로 사용)
    File? mapBgFile;
    try {
      _mapController?.clearPolyline();
      await Future.delayed(const Duration(milliseconds: 400));

      final boundary = _mapCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/map_bg_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(path).writeAsBytes(pngBytes);
        mapBgFile = File(path);
      }

      // 경로 복원
      if (routePts != null) {
        final pts = _routeData!
            .where((p) => p['lat'] != null && p['lng'] != null)
            .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
            .toList();
        _mapController?.addPolyline(polylines: [
          Polyline(
            polylineId: 'route',
            points: pts,
            strokeColor: AppColors.primary,
            strokeWidth: 4,
          ),
        ]);
      }
    } catch (e) {
      debugPrint('Map capture error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }

    // 이미지 편집 화면으로 이동
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditScreen(
          oreumName: stamp.oreumName,
          dateStr: dateStr,
          distanceKm: stamp.distanceWalked != null ? stamp.distanceWalked! / 1000 : null,
          durationMinutes: stamp.timeTaken,
          steps: stamp.steps,
          calories: stamp.calories,
          elevationGain: stamp.elevationGain,
          photoUrls: _photoUrls,
          routePoints: routePts,
          initialLocalPhoto: mapBgFile,
        ),
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
                if (_isSharing)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                else
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

    return RepaintBoundary(
      key: _mapCaptureKey,
      child: Stack(
      children: [
        kakaoMap,
        // 경로 없음 안내
        if (_routeData == null || _routeData!.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '경로 데이터가 없습니다',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
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
      ),
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

    // 기본 center: 경로 중간점 → 오름 좌표 → 제주 중심
    final defaultCenter = LatLng(widget.stamp.lat, widget.stamp.lng);

    return KakaoMap(
      onMapCreated: (controller) {
        _mapController = controller;
        // KakaoMap 플러그인은 didUpdateWidget에서만 polyline을 그리므로
        // 최초 생성 시 수동으로 추가해야 함
        controller.addPolyline(polylines: polylines);
        controller.addMarker(markers: markers.toList());
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
        ],
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

