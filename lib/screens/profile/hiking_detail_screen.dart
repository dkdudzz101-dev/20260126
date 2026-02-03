import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import '../../theme/app_colors.dart';
import '../../providers/stamp_provider.dart';
import '../../services/hiking_route_service.dart';
import '../../services/share_service.dart';
import '../../widgets/hiking_share_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    try {
      final data = await _routeService.getRouteWithPhotos(widget.stamp.id);
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
      }
    } catch (e) {
      debugPrint('경로 로드 실패: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareRecord() async {
    final stamp = widget.stamp;
    final dateStr = '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, '0')}.${stamp.stampedAt.day.toString().padLeft(2, '0')}';

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
              const Text(
                '공유 방식 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image, color: AppColors.primary),
                ),
                title: const Text('카드 이미지로 공유'),
                subtitle: const Text('기록 카드 이미지 생성'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final shareCard = HikingShareCard(
                      oreumName: stamp.oreumName,
                      date: dateStr,
                      distanceKm: (stamp.distanceWalked ?? 0) / 1000,
                      durationMinutes: stamp.timeTaken ?? 0,
                      steps: stamp.steps ?? 0,
                    );
                    await _shareService.shareWidget(
                      widget: shareCard,
                      oreumName: stamp.oreumName,
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('공유 실패: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.text_fields, color: Colors.blue),
                ),
                title: const Text('텍스트로 공유'),
                subtitle: const Text('등반 기록 텍스트'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _shareService.shareText(
                      oreumName: stamp.oreumName,
                      distanceKm: (stamp.distanceWalked ?? 0) / 1000,
                      durationMinutes: stamp.timeTaken ?? 0,
                      steps: stamp.steps,
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('공유 실패: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stamp.oreumName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareRecord,
            tooltip: '공유',
          ),
        ],
      ),
      body: Column(
        children: [
          // 지도 영역
          Expanded(
            flex: 2,
            child: _buildMap(),
          ),
          // 통계 영역
          Expanded(
            flex: 3,
            child: _buildStats(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final polylines = <Polyline>[];
    LatLng? center;

    if (_routeData != null && _routeData!.isNotEmpty) {
      final points = _routeData!
          .where((p) => p['lat'] != null && p['lng'] != null)
          .map((p) => LatLng(p['lat'].toDouble(), p['lng'].toDouble()))
          .toList();

      if (points.isNotEmpty) {
        center = points[points.length ~/ 2]; // 중앙 지점

        polylines.add(Polyline(
          polylineId: 'route',
          points: points,
          strokeColor: AppColors.primary,
          strokeWidth: 4,
        ));
      }
    }

    return KakaoMap(
      onMapCreated: (controller) {
        _mapController = controller;
        if (center != null) {
          controller.setCenter(center);
        }
      },
      center: center ?? LatLng(33.3617, 126.5292),
      currentLevel: 4,
      polylines: polylines,
    );
  }

  Widget _buildStats() {
    final stamp = widget.stamp;
    final dateStr = '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, '0')}.${stamp.stampedAt.day.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
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
          const SizedBox(height: 16),

          // 메인 통계
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
