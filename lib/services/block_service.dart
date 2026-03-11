import 'package:flutter/material.dart';
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

    try {
      // 이미 차단되어 있는지 확인
      final existing = await _client
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', userId)
          .eq('blocked_id', blockedUserId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('이미 차단된 사용자: $blockedUserId');
        return;
      }

      // 차단자(본인)가 public.users에 있는지 확인 (외래키 필수)
      await _ensureUserExists(userId);

      // 새로 차단
      await _client.from('blocked_users').insert({
        'blocker_id': userId,
        'blocked_id': blockedUserId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('차단 실패 상세: $e');
      rethrow;
    }
  }

  // public.users에 프로필이 없으면 생성 (외래키 위반 방지)
  Future<void> _ensureUserExists(String userId) async {
    try {
      final existing = await _client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        final email = _client.auth.currentUser?.email ?? '';
        await _client.from('users').upsert({
          'id': userId,
          'email': email,
          'nickname': '제주탐험가',
          'provider': 'unknown',
        });
        debugPrint('차단 전 누락된 사용자 프로필 자동 생성: $userId');
      }
    } catch (e) {
      debugPrint('사용자 존재 확인/생성 에러: $e');
    }
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
