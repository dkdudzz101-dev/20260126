import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/badge_model.dart';

class BadgeService {
  final _client = SupabaseConfig.client;

  // 전체 뱃지 목록 가져오기
  Future<List<BadgeModel>> getAllBadges() async {
    try {
      final response = await _client
          .from('badges')
          .select()
          .order('condition_value', ascending: true);

      return (response as List)
          .map((json) => BadgeModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('뱃지 로드 에러: $e');
      return [];
    }
  }

  // 사용자가 획득한 뱃지 목록 가져오기
  Future<List<String>> getUserBadgeIds(String userId) async {
    try {
      final response = await _client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      return (response as List)
          .map((row) => row['badge_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('사용자 뱃지 로드 에러: $e');
      return [];
    }
  }

  // 사용자가 획득한 뱃지 상세 정보 가져오기
  Future<List<BadgeModel>> getUserBadges(String userId) async {
    try {
      final response = await _client
          .from('user_badges')
          .select('badge_id, earned_at, badges(*)')
          .eq('user_id', userId);

      return (response as List).map((row) {
        final badgeJson = row['badges'] as Map<String, dynamic>;
        badgeJson['earned_at'] = row['earned_at'];
        return BadgeModel.fromJson(badgeJson);
      }).toList();
    } catch (e) {
      debugPrint('사용자 뱃지 상세 로드 에러: $e');
      return [];
    }
  }

  // 뱃지 획득 처리
  Future<bool> earnBadge(String userId, String badgeId) async {
    try {
      await _client.from('user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'earned_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('뱃지 획득 에러: $e');
      return false;
    }
  }

  // 조건에 따라 획득 가능한 뱃지 확인
  Future<List<BadgeModel>> checkEarnableBadges({
    required String userId,
    required int stampCount,
    required double totalDistance,
  }) async {
    try {
      // 모든 뱃지 로드
      final allBadges = await getAllBadges();

      // 이미 획득한 뱃지 ID
      final earnedBadgeIds = await getUserBadgeIds(userId);

      // 새로 획득 가능한 뱃지 확인
      final earnableBadges = <BadgeModel>[];

      for (final badge in allBadges) {
        // 이미 획득한 경우 스킵
        if (earnedBadgeIds.contains(badge.id)) continue;

        // 조건 확인
        bool earned = false;

        switch (badge.conditionType) {
          case 'oreum_count':
            earned = stampCount >= (badge.conditionValue ?? 0);
            break;
          case 'total_distance':
            earned = totalDistance >= (badge.conditionValue ?? 0);
            break;
          // 다른 조건들은 별도 로직 필요
        }

        if (earned) {
          earnableBadges.add(badge);
        }
      }

      return earnableBadges;
    } catch (e) {
      debugPrint('획득 가능 뱃지 확인 에러: $e');
      return [];
    }
  }
}
