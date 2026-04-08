import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import '../../theme/app_colors.dart';
import '../../services/share_service.dart';
import '../../widgets/hiking_share_card.dart';

enum _MarkerMode { title, route, mixed }

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
  });

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  final ShareService _shareService = ShareService();

  String? _selectedPhotoUrl;
  File? _localPhoto;
  bool _isProcessing = false;
  _MarkerMode _mode = _MarkerMode.mixed;

  bool get _hasRoute => widget.routePoints != null && widget.routePoints!.length >= 2;
  bool get _showRoute => _mode == _MarkerMode.route || _mode == _MarkerMode.mixed;
  bool get _showTitle => _mode == _MarkerMode.title || _mode == _MarkerMode.mixed;

  String _infoText() {
    final parts = <String>[];
    if (widget.distanceKm != null) parts.add('${widget.distanceKm!.toStringAsFixed(1)}km');
    if (widget.durationMinutes != null) {
      final m = widget.durationMinutes!;
      parts.add(m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분');
    }
    return parts.join(' | ');
  }

  @override
  void initState() {
    super.initState();
    _selectedPhotoUrl = (widget.photoUrls?.isNotEmpty ?? false)
        ? widget.photoUrls!.first
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D5E),
        foregroundColor: Colors.white,
        title: const Text('이미지 편집'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── 이미지 영역 ───────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) setState(() { _localPhoto = File(picked.path); _selectedPhotoUrl = null; });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 배경
                  _buildBg(),
                  // 경로 오버레이
                  if (_hasRoute && _showRoute)
                    CustomPaint(
                      painter: _RouteOverlayPainter(points: widget.routePoints!),
                    ),
                  // 워터마크
                  Positioned(
                    top: 12, right: 14,
                    child: Text('Oreum Pass', style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                    )),
                  ),
                  // 타이틀 + 정보
                  if (_showTitle)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xCC000000), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(widget.oreumName, style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                            )),
                            const Spacer(),
                            if (_infoText().isNotEmpty)
                              Text(_infoText(), style: const TextStyle(
                                color: Colors.white, fontSize: 14,
                              )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── 마커 선택 ─────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('마커 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _markerBtn(Icons.title, '타이틀', _MarkerMode.title),
                    const SizedBox(width: 10),
                    _markerBtn(Icons.route, '경로', _MarkerMode.route),
                    const SizedBox(width: 10),
                    _markerBtn(Icons.text_fields, '혼합', _MarkerMode.mixed),
                  ],
                ),
              ],
            ),
          ),

          // ── 공유 / 저장 버튼 ──────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleShare,
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(_isProcessing ? '...' : '< 공유', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D5E),
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
                      onPressed: _isProcessing ? null : _handleSave,
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: const Text('🖫 저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
  }

  Widget _markerBtn(IconData icon, String label, _MarkerMode mode) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E7D5E) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 26, color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[600],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBg() {
    if (_localPhoto != null) return Image.file(_localPhoto!, fit: BoxFit.cover);
    if (_selectedPhotoUrl != null) {
      return Image.network(_selectedPhotoUrl!, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E)));
    }
    return Container(color: const Color(0xFF1A1A2E));
  }

  HikingShareCard _buildShareCard() {
    return HikingShareCard(
      oreumName: widget.oreumName,
      date: null,
      distanceKm: _showTitle ? widget.distanceKm : null,
      durationMinutes: _showTitle ? widget.durationMinutes : null,
      steps: null,
      photoUrl: _localPhoto == null ? _selectedPhotoUrl : null,
      localPhotoFile: _localPhoto,
      calories: null,
      elevationGain: null,
      routePoints: (_hasRoute && _showRoute) ? widget.routePoints : null,
      showTitle: _showTitle,
      titleScale: 1.0,
      routeScale: 1.0,
      infoScale: 1.0,
    );
  }

  Future<void> _handleShare() async {
    setState(() => _isProcessing = true);
    try {
      final imagePath = await _shareService.captureWidget(widget: _buildShareCard());
      if (!mounted) return;
      await _shareService.shareImage(imagePath: imagePath, oreumName: widget.oreumName, text: '${widget.oreumName} 등반 완료!\n#JEJUOREUM #등산');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isProcessing = true);
    try {
      final imagePath = await _shareService.captureWidget(widget: _buildShareCard());
      await Gal.putImage(imagePath);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('갤러리에 저장되었습니다.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _RouteOverlayPainter extends CustomPainter {
  final List<Map<String, double>> points;
  _RouteOverlayPainter({required this.points});

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

    const pad = 40.0;
    final aW = size.width - pad * 2, aH = size.height - pad * 2;
    final ms = math.min(lngR > 0 ? aW / lngR : 1.0, latR > 0 ? aH / latR : 1.0);
    final ox = pad + (aW - lngR * ms) / 2;
    final oy = pad + (aH - latR * ms) / 2;

    Offset c(Map<String, double> p) => Offset(ox + (p['lng']! - minLng) * ms, oy + (maxLat - p['lat']!) * ms);

    final path = Path();
    path.moveTo(c(points.first).dx, c(points.first).dy);
    for (int i = 1; i < points.length; i++) { final pt = c(points[i]); path.lineTo(pt.dx, pt.dy); }

    canvas.drawPath(path, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    final s = c(points.first);
    canvas.drawCircle(s, 6, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(s, 3.5, Paint()..color = Colors.white);
    final e = c(points.last);
    canvas.drawCircle(e, 6, Paint()..color = Colors.redAccent);
    canvas.drawCircle(e, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RouteOverlayPainter old) => old.points.length != points.length;
}
