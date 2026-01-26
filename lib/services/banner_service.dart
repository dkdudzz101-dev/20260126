import 'package:flutter/material.dart';
import '../config/supabase_config.dart';

class BannerService {
  // 배너 이미지 목록 가져오기 (DB 테이블에서 조회)
  Future<List<String>> getBannerImages() async {
    debugPrint('배너 이미지 로드 시도...');

    try {
      // banners 테이블에서 배너 조회
      final response = await SupabaseConfig.client
          .from('banners')
          .select('image_url')
          .order('id', ascending: true);

      if (response.isNotEmpty) {
        final List<String> urls = [];
        for (final row in response) {
          final url = row['image_url'] as String?;
          if (url != null && url.isNotEmpty) {
            urls.add(url);
            debugPrint('배너 발견: $url');
          }
        }

        if (urls.isNotEmpty) {
          debugPrint('총 ${urls.length}개 배너 이미지 로드됨');
          return urls;
        }
      }
    } catch (e) {
      debugPrint('배너 로드 오류: $e');
    }

    // 배너 없으면 빈 목록 반환
    debugPrint('배너 이미지 없음');
    return [];
  }
}
