import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HikingShareCard extends StatelessWidget {
  final String oreumName;
  final String? date;
  final double? distanceKm;
  final int? durationMinutes;
  final int? steps;
  final String? photoUrl;
  final File? localPhotoFile;
  final int? calories;
  final double? elevationGain;
  /// 경로 좌표 리스트 [{lat, lng}, ...]
  final List<Map<String, double>>? routePoints;
  /// 타이틀(오름이름+정보) 표시 여부
  final bool showTitle;
  /// 타이틀 크기 배율
  final double titleScale;
  /// 경로 크기 배율
  final double routeScale;
  /// 정보 텍스트 크기 배율
  final double infoScale;

  const HikingShareCard({
    super.key,
    required this.oreumName,
    this.date,
    this.distanceKm,
    this.durationMinutes,
    this.steps,
    this.photoUrl,
    this.localPhotoFile,
    this.calories,
    this.elevationGain,
    this.routePoints,
    this.showTitle = true,
    this.titleScale = 1.0,
    this.routeScale = 1.0,
    this.infoScale = 1.0,
  });

  bool get _hasPhoto => photoUrl != null || localPhotoFile != null;
  bool get _hasRoute => routePoints != null && routePoints!.length >= 2;

  @override
  Widget build(BuildContext context) {
    if (_hasPhoto) {
      return _buildPhotoCard();
    }
    return _buildBasicCard();
  }

  // 사진 있을 때: 사진 위에 오버레이
  Widget _buildPhotoCard() {
    final infoParts = _buildInfoParts();

    return Container(
      width: 400,
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: localPhotoFile != null
                ? Image.file(localPhotoFile!, fit: BoxFit.cover)
                : Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.terrain, size: 64),
                    ),
                  ),
          ),
          // 그라데이션
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
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
          ),
          // 경로 오버레이
          if (_hasRoute)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                size: const Size(400, 500),
                painter: _ShareRouteOverlayPainter(
                  points: routePoints!,
                  strokeColor: Colors.white,
                  strokeWidth: 2.5 * routeScale,
                  scale: routeScale,
                ),
              ),
            ),
          // 워터마크
          Positioned(
            top: 16, right: 16,
            child: Text('제주오름', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13, fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            )),
          ),
          // 하단 정보
          if (showTitle)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(oreumName, style: TextStyle(
                      color: Colors.white, fontSize: 24 * titleScale, fontWeight: FontWeight.bold,
                    )),
                    if (infoParts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(infoParts.join('  |  '), style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85), fontSize: 12 * infoScale,
                      )),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 사진 없을 때: 기존 카드 스타일
  Widget _buildBasicCard() {
    final statItems = <Widget>[];
    if (distanceKm != null) {
      statItems.add(Expanded(child: _buildStatItem('거리', '${distanceKm!.toStringAsFixed(2)} km', Icons.straighten)));
    }
    if (durationMinutes != null) {
      statItems.add(Expanded(child: _buildStatItem('시간', _formatDuration(durationMinutes!), Icons.schedule)));
    }
    if (steps != null) {
      statItems.add(Expanded(child: _buildStatItem('걸음수', _formatNumber(steps!), Icons.directions_walk)));
    }
    if (calories != null) {
      statItems.add(Expanded(child: _buildStatItem('칼로리', '${calories}kcal', Icons.local_fire_department)));
    }
    if (elevationGain != null) {
      statItems.add(Expanded(child: _buildStatItem('고도', '+${elevationGain!.toStringAsFixed(0)}m', Icons.trending_up)));
    }

    // 2개씩 Row로 묶기
    final statRows = <Widget>[];
    for (int i = 0; i < statItems.length; i += 2) {
      if (i + 1 < statItems.length) {
        statRows.add(Row(children: [statItems[i], statItems[i + 1]]));
      } else {
        statRows.add(Row(children: [statItems[i], const Expanded(child: SizedBox())]));
      }
      if (i + 2 < statItems.length) statRows.add(const SizedBox(height: 12));
    }

    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: Text('제주오름', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70,
              letterSpacing: 1.0,
            )),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(oreumName, style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary,
                )),
                const SizedBox(height: 4),
                Text('등반 완료!', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (date != null)
            Text(date!, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          if (statRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: statRows),
            ),
          ],
          const SizedBox(height: 16),
          const Text('#제주오름 #등산 #오름탐험', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  List<String> _buildInfoParts() {
    final parts = <String>[];
    if (distanceKm != null) parts.add('${distanceKm!.toStringAsFixed(2)}km');
    if (durationMinutes != null) parts.add(_formatDuration(durationMinutes!));
    if (steps != null) parts.add('${_formatNumber(steps!)}걸음');
    if (calories != null) parts.add('${calories}kcal');
    if (elevationGain != null) parts.add('+${elevationGain!.toStringAsFixed(0)}m');
    if (date != null) parts.add(date!);
    return parts;
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white,
            )),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      return '${minutes ~/ 60}시간 ${minutes % 60}분';
    }
    return '$minutes분';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

/// 공유 카드용 경로 오버레이 페인터
class _ShareRouteOverlayPainter extends CustomPainter {
  final List<Map<String, double>> points;
  final Color strokeColor;
  final double strokeWidth;
  final double scale;

  _ShareRouteOverlayPainter({
    required this.points,
    this.strokeColor = Colors.white,
    this.strokeWidth = 2.5,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final firstLat = points.first['lat'];
    final firstLng = points.first['lng'];
    if (firstLat == null || firstLng == null) return;

    double minLat = firstLat;
    double maxLat = firstLat;
    double minLng = firstLng;
    double maxLng = firstLng;

    for (final p in points) {
      final lat = p['lat'];
      final lng = p['lng'];
      if (lat == null || lng == null) continue;
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    if (latRange == 0 && lngRange == 0) return;

    final padding = 30.0 / scale;
    final availableW = size.width - padding * 2;
    final availableH = size.height - padding * 2;

    final scaleX = lngRange > 0 ? availableW / lngRange : 1.0;
    final scaleY = latRange > 0 ? availableH / latRange : 1.0;
    final mapScale = math.min(scaleX, scaleY);

    final scaledW = lngRange * mapScale;
    final scaledH = latRange * mapScale;
    final offsetX = padding + (availableW - scaledW) / 2;
    final offsetY = padding + (availableH - scaledH) / 2;

    Offset toCanvas(Map<String, double> p) {
      return Offset(
        offsetX + ((p['lng'] ?? minLng) - minLng) * mapScale,
        offsetY + (maxLat - (p['lat'] ?? maxLat)) * mapScale,
      );
    }

    final path = Path();
    path.moveTo(toCanvas(points.first).dx, toCanvas(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      final pt = toCanvas(points[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    // 경로 그림자
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 경로 선
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 시작점
    final start = toCanvas(points.first);
    canvas.drawCircle(start, 5 * scale, Paint()..color = Colors.greenAccent);
    canvas.drawCircle(start, 3 * scale, Paint()..color = Colors.white);

    // 끝점
    final end = toCanvas(points.last);
    canvas.drawCircle(end, 5 * scale, Paint()..color = Colors.redAccent);
    canvas.drawCircle(end, 3 * scale, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ShareRouteOverlayPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
