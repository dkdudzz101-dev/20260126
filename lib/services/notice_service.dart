import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class NoticeService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 공지사항 목록 가져오기
  Future<List<Map<String, dynamic>>> getNotices() async {
    final response = await _client
        .from('notices')
        .select()
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 고정 공지사항만 가져오기
  Future<List<Map<String, dynamic>>> getPinnedNotices() async {
    final response = await _client
        .from('notices')
        .select()
        .eq('is_pinned', true)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 공지사항 상세 가져오기
  Future<Map<String, dynamic>?> getNoticeById(String noticeId) async {
    try {
      final response = await _client
          .from('notices')
          .select()
          .eq('id', noticeId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // 최신 공지사항 가져오기 (홈 화면용)
  Future<Map<String, dynamic>?> getLatestNotice() async {
    try {
      final response = await _client
          .from('notices')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }
}
