import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class BlockService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 사용자 차단
  Future<void> blockUser({
    required String blockedUserId,
    String? reason,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('blocked_users').insert({
      'blocker_id': userId,
      'blocked_id': blockedUserId,
      'reason': reason,
    });
  }

  // 사용자 차단 해제
  Future<void> unblockUser(String blockedUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', blockedUserId);
  }

  // 차단 목록 가져오기 (사용자 정보 포함)
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('blocked_users')
        .select('*, blocked:users!blocked_users_blocked_id_fkey(id, nickname, profile_image)')
        .eq('blocker_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 차단된 사용자 ID 목록만 가져오기 (피드 필터링용)
  Future<List<String>> getBlockedUserIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('blocked_users')
        .select('blocked_id')
        .eq('blocker_id', userId);

    return (response as List)
        .map<String>((e) => e['blocked_id'] as String)
        .toList();
  }
}
