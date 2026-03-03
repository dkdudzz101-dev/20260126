import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play 위치 권한 정책 준수를 위한 전체화면 위치 권한 설명 화면.
/// 첫 위치 권한 요청 전 반드시 이 화면을 표시해야 합니다 (prominent disclosure).
class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  /// SharedPreferences 키: 전체화면 공개를 이미 보여줬는지 여부
  static const String _disclosureShownKey = 'location_disclosure_shown';

  /// 전체화면 공개를 이미 표시했는지 확인
  static Future<bool> wasDisclosureShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_disclosureShownKey) ?? false;
  }

  /// 전체화면 공개 표시 완료 기록
  static Future<void> markDisclosureShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_disclosureShownKey, true);
  }

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
              // 위치 아이콘
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 52,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 32),
              // 타이틀
              const Text(
                '위치 권한 안내',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '제주오름 앱은 아래 목적으로 위치 정보를 사용합니다.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // 사용 목적 3가지
              _buildPurposeItem(
                icon: Icons.map_outlined,
                title: '지도에서 내 위치 및 가까운 오름 표시',
                description: '현재 위치를 기반으로 주변 오름을 찾아드립니다.',
              ),
              const SizedBox(height: 16),
              _buildPurposeItem(
                icon: Icons.hiking,
                title: '등산 GPS 경로 기록 및 정상 인증',
                description: '등산 중 이동 경로를 기록하고, 정상 도착 시 스탬프를 인증합니다.',
              ),
              const SizedBox(height: 16),
              _buildPurposeItem(
                icon: Icons.security,
                title: '위치 데이터는 기기에서만 사용',
                description: '수집된 위치 정보는 외부로 전송되지 않으며, 기기 내에서만 처리됩니다.',
              ),
              const Spacer(flex: 3),
              // 동의하고 계속 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _onAgree(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '동의하고 계속',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 나중에 버튼
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
                    '나중에',
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
            color: const Color(0xFF2196F3).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2196F3), size: 22),
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
    // 공개 표시 완료 기록
    await markDisclosureShown();

    // OS 위치 권한 요청
    final status = await Permission.locationWhenInUse.request();

    if (context.mounted) {
      Navigator.pop(context, status.isGranted);
    }
  }
}
