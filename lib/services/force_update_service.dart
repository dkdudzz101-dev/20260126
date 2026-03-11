import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';

class ForceUpdateService {
  // Supabase app_config 테이블에서 최소 버전 조회
  static Future<String?> getMinimumVersion() async {
    try {
      final response = await SupabaseConfig.client
          .from('app_config')
          .select('value')
          .eq('key', 'min_version')
          .maybeSingle();

      if (response != null) {
        return response['value'] as String?;
      }
    } catch (e) {
      debugPrint('최소 버전 조회 실패: $e');
    }
    return null;
  }

  // 버전 비교: current < minimum이면 true (업데이트 필요)
  static bool needsUpdate(String currentVersion, String minimumVersion) {
    final current = currentVersion.split('.').map(int.tryParse).toList();
    final minimum = minimumVersion.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < current.length ? (current[i] ?? 0) : 0;
      final m = i < minimum.length ? (minimum[i] ?? 0) : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  // 앱 시작 시 호출 - 업데이트 필요하면 다이얼로그 표시
  static Future<void> checkForUpdate(BuildContext context) async {
    final minVersion = await getMinimumVersion();
    if (minVersion == null) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (needsUpdate(currentVersion, minVersion)) {
      if (!context.mounted) return;
      _showForceUpdateDialog(context, currentVersion, minVersion);
    }
  }

  static void _showForceUpdateDialog(BuildContext context, String current, String minimum) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue),
              SizedBox(width: 8),
              Text('업데이트 필요'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '새로운 버전이 출시되었습니다.\n앱을 계속 사용하려면 업데이트가 필요합니다.',
              ),
              const SizedBox(height: 12),
              Text(
                '현재 버전: v$current\n최소 버전: v$minimum',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openStore(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('업데이트하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openStore() async {
    final Uri url;
    if (Platform.isAndroid) {
      url = Uri.parse('https://play.google.com/store/apps/details?id=com.jejuoreum.app');
    } else {
      // TODO: 심사 통과 후 실제 앱 ID로 교체 필요
      url = Uri.parse('https://apps.apple.com/kr/app/id0000000000');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
