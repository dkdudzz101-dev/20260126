import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
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
    final shareService = ShareService();
    final dateStr = '${stamp.stampedAt.year}.${stamp.stampedAt.month.toString().padLeft(2, "0")}.${stamp.stampedAt.day.toString().padLeft(2, "0")}';

    List<Map<String, double>>? routePts;
    if (_routeData != null && _routeData!.length >= 2) {
      routePts = _routeData!.map((p) => {
        'lat': (p['lat'] as num).toDouble(),
        'lng': (p['lng'] as num).toDouble(),
      }).toList();
    }

    String fmtTime(int m) => m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '${m}분';

    // 경로 숨기고 지도만 캡처 (배경으로 사용)
    File? mapBgFile;
    try {
      // 경로/마커 숨기기
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
    }

    // 지도 캡처 성공 → 경로 스티커 기본 추가(선택 상태), 실패 → 경로 스티커 기본 추가
    final List<_StickerItem> stickers = routePts != null
        ? [_StickerItem(kind: _StickerKind.route, dx: 0.05, dy: 0.05)]
        : [];
    int? selectedIdx = routePts != null ? 0 : null;
    bool isCapturing = false;
    String? selectedPhotoUrl = _photoUrls?.isNotEmpty == true ? _photoUrls!.first : null;
    File? localPhoto = mapBgFile;
    bool isProcessing = false;
    final previewKey = GlobalKey();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {

          Widget buildStickerContent(_StickerItem s) {
            switch (s.kind) {
              case _StickerKind.route:
                return SizedBox(
                  width: 110, height: 110,
                  child: CustomPaint(painter: _ShareRoutePainter(points: routePts!)),
                );
              case _StickerKind.stats:
                final sc = s.isWhiteText ? Colors.white : Colors.black;
                final shadow = Shadow(color: s.isWhiteText ? Colors.black54 : Colors.white54, blurRadius: 4);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stamp.distanceWalked != null)
                      Text('${(stamp.distanceWalked! / 1000).toStringAsFixed(1)} km',
                        style: TextStyle(color: sc, fontSize: 18, fontWeight: FontWeight.bold, shadows: [shadow])),
                    if (stamp.timeTaken != null)
                      Text(fmtTime(stamp.timeTaken!),
                        style: TextStyle(color: sc, fontSize: 13, shadows: [shadow])),
                    if (stamp.calories != null)
                      Text('${stamp.calories} kcal',
                        style: TextStyle(color: sc, fontSize: 13, shadows: [shadow])),
                  ],
                );
              case _StickerKind.date:
                final dc = s.isWhiteText ? Colors.white : Colors.black;
                final dshadow = Shadow(color: s.isWhiteText ? Colors.black54 : Colors.white54, blurRadius: 4);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stamp.oreumName,
                      style: TextStyle(color: dc, fontSize: 16, fontWeight: FontWeight.bold, shadows: [dshadow])),
                    Text(dateStr,
                      style: TextStyle(color: dc.withValues(alpha: 0.85), fontSize: 12, shadows: [dshadow])),
                  ],
                );
              case _StickerKind.all:
                return Container(
                  width: 130,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (routePts != null)
                        SizedBox(
                          width: 110, height: 80,
                          child: CustomPaint(painter: _ShareRoutePainter(points: routePts)),
                        ),
                      const SizedBox(height: 6),
                      Text(stamp.oreumName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(dateStr,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      if (stamp.distanceWalked != null)
                        Text('${(stamp.distanceWalked! / 1000).toStringAsFixed(1)} km',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                );
            }
          }

          Widget buildStickerWidget(int idx, _StickerItem s, double pw, double ph) {
            final isSelected = !isCapturing && selectedIdx == idx;
            return Positioned(
              left: s.dx * pw,
              top: s.dy * ph,
              child: GestureDetector(
                onTap: () => setSheet(() => selectedIdx = idx),
                onScaleStart: (d) { s.gestureBaseScale = s.scale; },
                onScaleUpdate: (d) => setSheet(() {
                  if (d.pointerCount >= 2) {
                    s.scale = (s.gestureBaseScale * d.scale).clamp(0.4, 4.0);
                  } else {
                    s.dx = (s.dx + d.focalPointDelta.dx / pw).clamp(0.0, 0.9);
                    s.dy = (s.dy + d.focalPointDelta.dy / ph).clamp(0.0, 0.9);
                  }
                }),
                child: Transform.scale(
                  scale: s.scale,
                  alignment: Alignment.topLeft,
                  child: Stack(
                    children: [
                      buildStickerContent(s),
                      if (isSelected)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(8),
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

          Future<String> capturePreview() async {
            setSheet(() { isCapturing = true; selectedIdx = null; });
            await Future.delayed(const Duration(milliseconds: 80));
            try {
              final boundary = previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 3.0);
              final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
              final pngBytes = byteData!.buffer.asUint8List();
              final directory = await getTemporaryDirectory();
              final path = '${directory.path}/jeju_oreum_${DateTime.now().millisecondsSinceEpoch}.png';
              await File(path).writeAsBytes(pngBytes);
              return path;
            } finally {
              setSheet(() => isCapturing = false);
            }
          }

          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 10),
                const Text('이미지 편집', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final pw = constraints.maxWidth;
                          final ph = constraints.maxHeight;
                          return GestureDetector(
                            onTap: () => setSheet(() => selectedIdx = null),
                            child: RepaintBoundary(
                              key: previewKey,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (localPhoto != null)
                                    Image.file(localPhoto!, fit: BoxFit.cover)
                                  else if (selectedPhotoUrl != null)
                                    Image.network(selectedPhotoUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E)))
                                  else
                                    Container(color: const Color(0xFF1A1A2E)),
                                  Positioned(
                                    top: 10, right: 12,
                                    child: Text('JEJUOREUM', style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2,
                                    )),
                                  ),
                                  ...stickers.asMap().entries.map(
                                    (e) => buildStickerWidget(e.key, e.value, pw, ph),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // 선택된 스티커 컨트롤 툴바
                if (selectedIdx != null && !isCapturing && selectedIdx! < stickers.length)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 삭제
                        GestureDetector(
                          onTap: () => setSheet(() {
                            stickers.removeAt(selectedIdx!);
                            selectedIdx = null;
                          }),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 26),
                              SizedBox(height: 2),
                              Text('삭제', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        // 글자색 토글 (기록/날짜만)
                        if (stickers[selectedIdx!].kind == _StickerKind.stats || stickers[selectedIdx!].kind == _StickerKind.date)
                          GestureDetector(
                            onTap: () => setSheet(() => stickers[selectedIdx!].isWhiteText = !stickers[selectedIdx!].isWhiteText),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: stickers[selectedIdx!].isWhiteText ? Colors.white : Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white54, width: 1.5),
                                  ),
                                  child: Center(child: Text('A', style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold,
                                    color: stickers[selectedIdx!].isWhiteText ? Colors.black : Colors.white,
                                  ))),
                                ),
                                const SizedBox(height: 2),
                                Text(stickers[selectedIdx!].isWhiteText ? '흰색' : '검정',
                                  style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        // 축소
                        GestureDetector(
                          onTap: () => setSheet(() {
                            stickers[selectedIdx!].scale = (stickers[selectedIdx!].scale - 0.15).clamp(0.4, 4.0);
                          }),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.remove_circle_outline, color: Colors.white70, size: 26),
                              SizedBox(height: 2),
                              Text('축소', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        // 확대
                        GestureDetector(
                          onTap: () => setSheet(() {
                            stickers[selectedIdx!].scale = (stickers[selectedIdx!].scale + 0.15).clamp(0.4, 4.0);
                          }),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_circle_outline, color: Colors.white70, size: 26),
                              SizedBox(height: 2),
                              Text('확대', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        // 완료
                        GestureDetector(
                          onTap: () => setSheet(() => selectedIdx = null),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 26),
                              SizedBox(height: 2),
                              Text('완료', style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final p = await ImagePicker().pickImage(source: ImageSource.gallery);
                            if (p != null) setSheet(() { localPhoto = File(p.path); selectedPhotoUrl = null; });
                          },
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('갤러리'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final p = await ImagePicker().pickImage(source: ImageSource.camera);
                            if (p != null) setSheet(() { localPhoto = File(p.path); selectedPhotoUrl = null; });
                          },
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('카메라'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('스티커 추가', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _stickerBtn('경로', Icons.route,
                            enabled: routePts != null,
                            onTap: () => setSheet(() { stickers.add(_StickerItem(kind: _StickerKind.route)); selectedIdx = stickers.length - 1; }),
                          ),
                          const SizedBox(width: 8),
                          _stickerBtn('기록', Icons.straighten,
                            onTap: () => setSheet(() { stickers.add(_StickerItem(kind: _StickerKind.stats)); selectedIdx = stickers.length - 1; }),
                          ),
                          const SizedBox(width: 8),
                          _stickerBtn('날짜', Icons.calendar_today,
                            onTap: () => setSheet(() { stickers.add(_StickerItem(kind: _StickerKind.date)); selectedIdx = stickers.length - 1; }),
                          ),
                          const SizedBox(width: 8),
                          _stickerBtn('전체', Icons.layers,
                            enabled: routePts != null,
                            onTap: () => setSheet(() { stickers.add(_StickerItem(kind: _StickerKind.all)); selectedIdx = stickers.length - 1; }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(sheetCtx).padding.bottom + 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : () async {
                              setSheet(() => isProcessing = true);
                              try {
                                final imagePath = await capturePreview();
                                if (!mounted) return;
                                Navigator.pop(sheetCtx);
                                await shareService.shareImage(imagePath: imagePath, oreumName: stamp.oreumName, text: '${stamp.oreumName} 등반 완료!\n#제주오름 #등산');
                              } catch (e) {
                                setSheet(() => isProcessing = false);
                              }
                            },
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('공유', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : () async {
                              setSheet(() => isProcessing = true);
                              try {
                                final imagePath = await capturePreview();
                                await Gal.putImage(imagePath);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('갤러리에 저장되었습니다.')));
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
                              } finally {
                                setSheet(() => isProcessing = false);
                              }
                            },
                            icon: const Icon(Icons.save_alt, size: 18),
                            label: const Text('저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[400],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (mounted && widget.autoShare) Navigator.pop(context);
  }

  Widget _stickerBtn(String label, IconData icon, {required VoidCallback onTap, bool enabled = true}) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: enabled ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: enabled ? AppColors.primary : Colors.grey),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: enabled ? AppColors.primary : Colors.grey,
              )),
            ],
          ),
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

enum _StickerKind { route, stats, date, all }

class _StickerItem {
  final _StickerKind kind;
  double dx;
  double dy;
  double scale;
  bool isWhiteText;
  double gestureBaseScale = 1.0;
  _StickerItem({required this.kind, this.dx = 0.1, this.dy = 0.1, this.scale = 1.0, this.isWhiteText = true});
}

class _ShareRoutePainter extends CustomPainter {
  final List<Map<String, double>> points;
  _ShareRoutePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    double minLat = points.first['lat']!, maxLat = minLat;
    double minLng = points.first['lng']!, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p['lat']!); maxLat = math.max(maxLat, p['lat']!);
      minLng = math.min(minLng, p['lng']!); maxLng = math.max(maxLng, p['lng']!);
    }
    final latR = maxLat - minLat, lngR = maxLng - minLng;
    if (latR == 0 && lngR == 0) return;

    const pad = 30.0;
    final aW = size.width - pad * 2, aH = size.height - pad * 2;
    final ms = math.min(lngR > 0 ? aW / lngR : 1.0, latR > 0 ? aH / latR : 1.0);
    final ox = pad + (aW - lngR * ms) / 2;
    final oy = pad + (aH - latR * ms) / 2;

    Offset c(Map<String, double> p) => Offset(ox + (p['lng']! - minLng) * ms, oy + (maxLat - p['lat']!) * ms);

    final path = Path();
    path.moveTo(c(points.first).dx, c(points.first).dy);
    for (int i = 1; i < points.length; i++) { final pt = c(points[i]); path.lineTo(pt.dx, pt.dy); }

    canvas.drawPath(path, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    final s = c(points.first);
    canvas.drawCircle(s, 5, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(s, 3, Paint()..color = Colors.white);
    final e = c(points.last);
    canvas.drawCircle(e, 5, Paint()..color = Colors.redAccent);
    canvas.drawCircle(e, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ShareRoutePainter old) => old.points.length != points.length;
}
