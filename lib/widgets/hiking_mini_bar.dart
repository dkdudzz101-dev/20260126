import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hiking_provider.dart';
import '../screens/hiking/hiking_screen.dart';
import '../theme/app_colors.dart';

/// 등산 중일 때 하단에 표시되는 미니바.
/// 탭하면 등산 화면으로 복귀.
class HikingMiniBar extends StatelessWidget {
  const HikingMiniBar({super.key});

  @override
  Widget build(BuildContext context) {
    final hiking = context.watch<HikingProvider>();
    if (!hiking.isHiking || hiking.currentOreum == null) {
      return const SizedBox.shrink();
    }

    final totalDist = hiking.isDescending
        ? (hiking.ascentDistance + hiking.descentDistance)
        : hiking.totalDistance;
    final distStr = totalDist >= 1000
        ? '${(totalDist / 1000).toStringAsFixed(1)}km'
        : '${totalDist.toStringAsFixed(0)}m';
    final secs = hiking.elapsedSeconds;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    final timeStr = h > 0
        ? '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m}:${s.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HikingScreen(oreum: hiking.currentOreum!),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.hiking, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${hiking.currentOreum!.name} 등산 중',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$distStr · $timeStr · ${hiking.hikingSteps}걸음',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
