import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ShareService {
  final ScreenshotController screenshotController = ScreenshotController();

  /// 위젯을 이미지로 캡처 후 공유
  Future<void> shareWidget({
    required Widget widget,
    required String oreumName,
    String? text,
  }) async {
    try {
      // 위젯 캡처
      final imageBytes = await screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: widget,
        ),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );

      // 임시 파일로 저장
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/jeju_oreum_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      // 공유
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: text ?? '$oreumName 등반 완료! #제주오름 #등산',
        subject: '제주오름 등반 기록',
      );

      // 임시 파일 삭제 (일정 시간 후)
      Future.delayed(const Duration(minutes: 5), () {
        if (imageFile.existsSync()) {
          imageFile.deleteSync();
        }
      });
    } catch (e) {
      debugPrint('공유 실패: $e');
      rethrow;
    }
  }

  /// 텍스트만 공유
  Future<void> shareText({
    required String oreumName,
    required double distanceKm,
    required int durationMinutes,
    required int calories,
    required double elevationGain,
  }) async {
    final text = '''
제주오름 등반 기록

$oreumName 등반 완료!

거리: ${distanceKm.toStringAsFixed(2)} km
시간: ${_formatDuration(durationMinutes)}
칼로리: $calories kcal
상승 고도: ${elevationGain.toStringAsFixed(0)} m

#제주오름 #등산 #오름탐험
''';

    await Share.share(text, subject: '$oreumName 등반 기록');
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      return '${minutes ~/ 60}시간 ${minutes % 60}분';
    }
    return '$minutes분';
  }
}
