import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Google Play 정책 준수를 위한 백그라운드 위치 권한 전체화면 공개 화면.
/// 등산 시작 시 "항상 허용"(locationAlways) 요청 전 반드시 표시해야 합니다.
class BackgroundLocationPermissionScreen extends StatelessWidget {
  const BackgroundLocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 아이콘
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hiking,
                  size: 52,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 32),
              // 타이틀
              const Text(
                '백그라운드 위치 권한 안내',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '등산 중 화면을 꺼도 경로 기록이 유지되려면\n위치 권한을 "항상 허용"으로 설정해야 합니다.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // 사용 목적
              _buildPurposeItem(
                icon: Icons.route,
                title: '등산 중 GPS 경로 기록',
                description: '이동 거리, 고도, 소요 시간을 정확하게 측정합니다.',
              ),
              const SizedBox(height: 16),
              _buildPurposeItem(
                icon: Icons.flag,
                title: '정상 도착 자동 인증',
                description: '오름 정상 100m 이내 도달 시 자동으로 스탬프를 인증합니다.',
              ),
              const SizedBox(height: 16),
              _buildPurposeItem(
                icon: Icons.power_settings_new,
                title: '등산 종료 시 즉시 중단',
                description: '등산을 종료하면 백그라운드 위치 수집이 즉시 중단됩니다.',
              ),
              const SizedBox(height: 16),
              _buildPurposeItem(
                icon: Icons.directions_walk,
                title: '걸음수 측정',
                description: '신체 활동 정보를 사용하여 등산 중 걸음수와 칼로리를 측정합니다.',
              ),
              const SizedBox(height: 20),
              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFF8F00), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '다음 화면에서 위치 권한을 "항상 허용"으로, 신체 활동 권한을 "허용"으로 설정해주세요.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              // 동의하고 계속 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _onAgree(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '계속',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 거부 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '거부',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4CAF50), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onAgree(BuildContext context) async {
    // 포그라운드 권한은 _startHiking에서 이미 확보된 상태
    // 백그라운드 위치 권한 요청 (Android 10+에서 시스템 설정으로 이동할 수 있으므로 타임아웃 적용)
    bool granted = false;
    try {
      final result = await Permission.locationAlways.request()
          .timeout(const Duration(seconds: 20), onTimeout: () => PermissionStatus.denied);
      granted = result.isGranted;
    } catch (_) {
      granted = false;
    }

    if (!context.mounted) return;

    // "항상 허용"이 아닌 경우 설정으로 재안내
    if (!granted) {
      await _showSettingsGuideDialog(context);
      return;
    }

    // 신체 활동(걸음수) 권한 요청
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _showSettingsGuideDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '항상 허용 설정 필요',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '등산 중 화면을 꺼도 경로가 기록되려면\n위치 권한을 "항상 허용"으로 설정해야 합니다.\n\n설정 앱에서\n위치 → 항상 허용\n으로 변경해주세요.',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, false); // 설정 거부 → 그냥 시작
            },
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings(); // 설정 앱 이동
              // 설정에서 돌아왔을 때 권한 재확인
              if (context.mounted) {
                final status = await Permission.locationAlways.status;
                Navigator.pop(context, status.isGranted);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }
}
