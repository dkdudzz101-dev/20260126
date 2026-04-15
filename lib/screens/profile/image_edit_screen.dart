import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// 스티커 타입
// ─────────────────────────────────────────────
enum _StickerType {
  oreumName,
  distance,
  duration,
  steps,
  calories,
  elevation,
  route, // 전체화면 경로 오버레이 (위치 없음)
}

class _StickerDef {
  final _StickerType type;
  final IconData icon;
  final String label;
  const _StickerDef(this.type, this.icon, this.label);
}

// ─────────────────────────────────────────────
// 캔버스 위 배치된 스티커 (route 제외)
// ─────────────────────────────────────────────
class _PlacedSticker {
  final _StickerType type;
  Offset pos; // 정규화 좌표 (0.0 ~ 1.0)

  _PlacedSticker({required this.type, required this.pos});
}

// ─────────────────────────────────────────────
// 배경 그라데이션 프리셋
// ─────────────────────────────────────────────
const List<List<Color>> _kGradients = [
  [Color(0xFF1A1A2E), Color(0xFF16213E)],   // 다크 네이비
  [Color(0xFF1B5E20), Color(0xFF2E7D32)],   // 딥 그린
  [Color(0xFF0D47A1), Color(0xFF1565C0)],   // 딥 블루
  [Color(0xFF4A148C), Color(0xFF6A1B9A)],   // 퍼플
  [Color(0xFF212121), Color(0xFF424242)],   // 다크 그레이
  [Color(0xFF4E342E), Color(0xFF6D4C41)],   // 브라운
];

// ─────────────────────────────────────────────
// 화면
// ─────────────────────────────────────────────
class ImageEditScreen extends StatefulWidget {
  final String oreumName;
  final String dateStr;
  final double? distanceKm;
  final int? durationMinutes;
  final int? steps;
  final int? calories;
  final double? elevationGain;
  final List<String>? photoUrls;
  final List<Map<String, double>>? routePoints;
  final String? recordType;
  final File? initialLocalPhoto;

  const ImageEditScreen({
    super.key,
    required this.oreumName,
    required this.dateStr,
    this.distanceKm,
    this.durationMinutes,
    this.steps,
    this.calories,
    this.elevationGain,
    this.photoUrls,
    this.routePoints,
    this.recordType,
    this.initialLocalPhoto,
  });

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen>
    with SingleTickerProviderStateMixin {
  // ── 캡처 키 ──────────────────────────────────
  final GlobalKey _captureKey = GlobalKey();

  // ── 탭 ───────────────────────────────────────
  late TabController _tabController;

  // ── 배경 ─────────────────────────────────────
  int _selectedGradient = 0;
  File? _bgPhoto;

  // ── 스티커 ───────────────────────────────────
  final List<_PlacedSticker> _stickers = [];
  bool _showRoute = false;
  Color _textColor = Colors.white;

  // ── 상태 ─────────────────────────────────────
  bool _isProcessing = false;
  Size _canvasSize = Size.zero;

  // ─── 사용 가능한 스티커 정의 (데이터 있는 것만) ─
  List<_StickerDef> get _availableDefs {
    final list = <_StickerDef>[
      const _StickerDef(_StickerType.oreumName, Icons.terrain, '오름 이름'),
      if (widget.distanceKm != null)
        const _StickerDef(_StickerType.distance, Icons.straighten, '이동거리'),
      if (widget.durationMinutes != null)
        const _StickerDef(_StickerType.duration, Icons.timer_outlined, '소요시간'),
      if (widget.steps != null)
        const _StickerDef(_StickerType.steps, Icons.directions_walk, '걸음수'),
      if (widget.calories != null)
        const _StickerDef(_StickerType.calories, Icons.local_fire_department, '칼로리'),
      if (widget.elevationGain != null)
        const _StickerDef(_StickerType.elevation, Icons.trending_up, '고도'),
      if (_hasRouteData)
        const _StickerDef(_StickerType.route, Icons.route, '경로'),
    ];
    return list;
  }

  bool get _hasRouteData =>
      widget.routePoints != null && widget.routePoints!.length >= 2;

  bool _isStickerActive(_StickerType type) {
    if (type == _StickerType.route) return _showRoute;
    return _stickers.any((s) => s.type == type);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initDefaultStickers();
  }

  void _initDefaultStickers() {
    // 기본: 오름 이름 + 있으면 거리 + 시간
    _stickers.add(_PlacedSticker(type: _StickerType.oreumName, pos: const Offset(0.05, 0.70)));
    if (widget.distanceKm != null) {
      _stickers.add(_PlacedSticker(type: _StickerType.distance, pos: const Offset(0.05, 0.52)));
    }
    if (widget.durationMinutes != null) {
      _stickers.add(_PlacedSticker(
          type: _StickerType.duration,
          pos: Offset(widget.distanceKm != null ? 0.50 : 0.05, 0.52)));
    }
    if (_hasRouteData) _showRoute = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('공유 카드 편집',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _handleShare,
              child: const Text('공유',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 캔버스 ────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: LayoutBuilder(builder: (ctx, constraints) {
                  _canvasSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return RepaintBoundary(
                    key: _captureKey,
                    child: _buildCanvas(),
                  );
                }),
              ),
            ),
          ),

          // ── 하단 패널 ─────────────────────────
          Container(
            color: const Color(0xFF1C1C1C),
            height: 260,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: '스티커'),
                    Tab(text: '배경'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStickerPanel(),
                      _buildBgPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 액션 버튼 ─────────────────────────
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _handleSave,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('저장',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleShare,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('공유하기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
  }

  // ─────────────────────────────────────────────
  // 캔버스
  // ─────────────────────────────────────────────
  Widget _buildCanvas() {
    return ClipRect(
      child: Stack(
        children: [
          // 배경
          Positioned.fill(child: _buildBackground()),

          // 경로 오버레이
          if (_showRoute && _hasRouteData)
            Positioned.fill(
              child: CustomPaint(
                painter: _RouteOverlayPainter(points: widget.routePoints!),
              ),
            ),

          // 드래그 가능한 스티커들
          for (final sticker in _stickers) _buildDraggableSticker(sticker),

          // 워터마크
          Positioned(
            top: 12,
            right: 14,
            child: Text(
              'JEJUOREUM',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_bgPhoto != null) {
      return Image.file(_bgPhoto!, fit: BoxFit.cover);
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _kGradients[_selectedGradient]
              .map((c) => c)
              .toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 드래그 스티커
  // ─────────────────────────────────────────────
  Widget _buildDraggableSticker(_PlacedSticker sticker) {
    final x = sticker.pos.dx * _canvasSize.width;
    final y = sticker.pos.dy * _canvasSize.height;

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (_canvasSize == Size.zero) return;
          setState(() {
            sticker.pos = Offset(
              (sticker.pos.dx + details.delta.dx / _canvasSize.width)
                  .clamp(0.0, 0.85),
              (sticker.pos.dy + details.delta.dy / _canvasSize.height)
                  .clamp(0.0, 0.90),
            );
          });
        },
        onLongPress: () {
          setState(() => _stickers.remove(sticker));
        },
        child: _StickerCard(
          type: sticker.type,
          oreumName: widget.oreumName,
          dateStr: widget.dateStr,
          distanceKm: widget.distanceKm,
          durationMinutes: widget.durationMinutes,
          steps: widget.steps,
          calories: widget.calories,
          elevationGain: widget.elevationGain,
          textColor: _textColor,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 스티커 패널
  // ─────────────────────────────────────────────
  // 텍스트 색상 프리셋
  static const List<Color> _textColors = [
    Colors.white,
    Colors.black,
    AppColors.primary,       // 골드
    Color(0xFF4CAF50),       // 그린
    Color(0xFF64B5F6),       // 스카이블루
    Color(0xFFFF8A65),       // 오렌지
    Color(0xFFCE93D8),       // 라벤더
  ];

  Widget _buildStickerPanel() {
    final defs = _availableDefs;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 스티커 토글 그리드
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: defs.map((def) {
              final active = _isStickerActive(def.type);
              return GestureDetector(
                onTap: () => _toggleSticker(def.type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? AppColors.primary : Colors.white12,
                      width: active ? 1.8 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(def.icon,
                          color: active ? AppColors.primary : Colors.white54,
                          size: 24),
                      const SizedBox(height: 5),
                      Text(
                        def.label,
                        style: TextStyle(
                          color: active ? AppColors.primary : Colors.white54,
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // 텍스트 색상 선택
          const SizedBox(height: 12),
          const Text('글씨 색상',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: _textColors.map((color) {
              final isSelected = _textColor == color;
              return GestureDetector(
                onTap: () => setState(() => _textColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white24,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          size: 16,
                          color: color == Colors.white || color == AppColors.primary
                              ? Colors.black
                              : Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _toggleSticker(_StickerType type) {
    setState(() {
      if (type == _StickerType.route) {
        _showRoute = !_showRoute;
        return;
      }
      if (_isStickerActive(type)) {
        _stickers.removeWhere((s) => s.type == type);
      } else {
        // 기본 배치 위치
        final pos = _defaultPos(type);
        _stickers.add(_PlacedSticker(type: type, pos: pos));
      }
    });
  }

  Offset _defaultPos(_StickerType type) {
    switch (type) {
      case _StickerType.oreumName:
        return const Offset(0.05, 0.70);
      case _StickerType.distance:
        return const Offset(0.05, 0.52);
      case _StickerType.duration:
        return const Offset(0.50, 0.52);
      case _StickerType.steps:
        return const Offset(0.05, 0.62);
      case _StickerType.calories:
        return const Offset(0.50, 0.62);
      case _StickerType.elevation:
        return const Offset(0.05, 0.35);
      default:
        return const Offset(0.20, 0.40);
    }
  }

  // ─────────────────────────────────────────────
  // 배경 패널
  // ─────────────────────────────────────────────
  Widget _buildBgPanel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          // 갤러리 버튼
          _BgThumb(
            isSelected: false,
            onTap: _pickPhoto,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library_outlined,
                    color: Colors.white54, size: 26),
                const SizedBox(height: 4),
                Text('갤러리',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 선택한 사진 미리보기
          if (_bgPhoto != null) ...[
            _BgThumb(
              isSelected: true,
              onTap: () => setState(() => _bgPhoto = null),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(_bgPhoto!, fit: BoxFit.cover),
                  ),
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],

          // 그라데이션 프리셋
          ...List.generate(_kGradients.length, (i) {
            final isSelected = _bgPhoto == null && _selectedGradient == i;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _BgThumb(
                isSelected: isSelected,
                onTap: () => setState(() {
                  _bgPhoto = null;
                  _selectedGradient = i;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _kGradients[i].map((c) => c).toList(),
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _bgPhoto = File(picked.path));
    }
  }

  // ─────────────────────────────────────────────
  // 캡처
  // ─────────────────────────────────────────────
  Future<String> _capture() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('캡처 실패');
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('이미지 변환 실패');
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/jeju_oreum_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<void> _handleShare() async {
    setState(() => _isProcessing = true);
    try {
      final path = await _capture();
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        text: '${widget.oreumName} 등반 완료! #제주오름 #등산',
        subject: '제주오름 등반 기록',
      );
      Future.delayed(const Duration(minutes: 5), () {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('공유에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isProcessing = true);
    try {
      final path = await _capture();
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('갤러리에 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

// ─────────────────────────────────────────────
// 스티커 카드 위젯
// ─────────────────────────────────────────────
class _StickerCard extends StatelessWidget {
  final _StickerType type;
  final String oreumName;
  final String dateStr;
  final double? distanceKm;
  final int? durationMinutes;
  final int? steps;
  final int? calories;
  final double? elevationGain;
  final Color textColor;

  const _StickerCard({
    required this.type,
    required this.oreumName,
    required this.dateStr,
    this.distanceKm,
    this.durationMinutes,
    this.steps,
    this.calories,
    this.elevationGain,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (type == _StickerType.oreumName) return _buildNameSticker();
    return _buildStatSticker();
  }

  Widget _buildNameSticker() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            oreumName,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSticker() {
    final data = _getStickerData();
    if (data == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.65),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _StickerData? _getStickerData() {
    switch (type) {
      case _StickerType.distance:
        if (distanceKm == null) return null;
        return _StickerData(
          icon: Icons.straighten,
          label: '이동거리',
          value: '${distanceKm!.toStringAsFixed(2)} km',
        );
      case _StickerType.duration:
        if (durationMinutes == null) return null;
        return _StickerData(
          icon: Icons.timer_outlined,
          label: '소요시간',
          value: _formatDuration(durationMinutes!),
        );
      case _StickerType.steps:
        if (steps == null) return null;
        return _StickerData(
          icon: Icons.directions_walk,
          label: '걸음수',
          value: _formatNumber(steps!),
        );
      case _StickerType.calories:
        if (calories == null) return null;
        return _StickerData(
          icon: Icons.local_fire_department,
          label: '칼로리',
          value: '${calories!} kcal',
        );
      case _StickerType.elevation:
        if (elevationGain == null) return null;
        return _StickerData(
          icon: Icons.trending_up,
          label: '고도',
          value: '+${elevationGain!.toStringAsFixed(0)} m',
        );
      default:
        return null;
    }
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

class _StickerData {
  final IconData icon;
  final String label;
  final String value;
  const _StickerData(
      {required this.icon, required this.label, required this.value});
}

// ─────────────────────────────────────────────
// 배경 썸네일 위젯
// ─────────────────────────────────────────────
class _BgThumb extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _BgThumb(
      {required this.isSelected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 62,
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white12,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 경로 오버레이 페인터
// ─────────────────────────────────────────────
class _RouteOverlayPainter extends CustomPainter {
  final List<Map<String, double>> points;

  const _RouteOverlayPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double minLat = points.first['lat']!, maxLat = minLat;
    double minLng = points.first['lng']!, maxLng = minLng;

    for (final p in points) {
      final lat = p['lat'];
      final lng = p['lng'];
      if (lat == null || lng == null) continue;
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }

    final latR = maxLat - minLat;
    final lngR = maxLng - minLng;
    if (latR == 0 && lngR == 0) return;

    const pad = 40.0;
    final aW = size.width - pad * 2;
    final aH = size.height - pad * 2;
    final ms =
        math.min(lngR > 0 ? aW / lngR : 1.0, latR > 0 ? aH / latR : 1.0);
    final ox = pad + (aW - lngR * ms) / 2;
    final oy = pad + (aH - latR * ms) / 2;

    Offset c(Map<String, double> p) => Offset(
          ox + ((p['lng'] ?? minLng) - minLng) * ms,
          oy + (maxLat - (p['lat'] ?? maxLat)) * ms,
        );

    final path = Path();
    path.moveTo(c(points.first).dx, c(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      final pt = c(points[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    // 그림자
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // 경로 선
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // 시작점
    final s = c(points.first);
    canvas.drawCircle(s, 6, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(s, 3.5, Paint()..color = Colors.white);

    // 끝점
    final e = c(points.last);
    canvas.drawCircle(e, 6, Paint()..color = Colors.redAccent);
    canvas.drawCircle(e, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RouteOverlayPainter old) =>
      old.points.length != points.length;
}
