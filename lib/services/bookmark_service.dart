import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class BookmarkService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 북마크 목록 가져오기
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('bookmarks')
        .select('*, oreums(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 북마크 토글
  Future<bool> toggleBookmark(String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    // 이미 북마크 했는지 확인
    final existing = await _client
        .from('bookmarks')
        .select('id')
        .eq('user_id', userId)
        .eq('oreum_id', oreumId);

    if ((existing as List).isNotEmpty) {
      // 북마크 삭제
      await _client
          .from('bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('oreum_id', oreumId);
      return false;
    } else {
      // 북마크 추가
      await _client.from('bookmarks').insert({
        'user_id': userId,
        'oreum_id': oreumId,
      });
      return true;
    }
  }

  // 북마크 여부 확인
  Future<bool> isBookmarked(String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('bookmarks')
        .select('id')
        .eq('user_id', userId)
        .eq('oreum_id', oreumId);

    return (response as List).isNotEmpty;
  }

  // 북마크 수 가져오기
  Future<int> getBookmarkCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _client
        .from('bookmarks')
        .select('id')
        .eq('user_id', userId);

    return (response as List).length;
  }
}
