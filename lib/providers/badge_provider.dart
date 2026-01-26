import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';

class BadgeProvider extends ChangeNotifier {
  final BadgeService _badgeService = BadgeService();

  List<BadgeModel> _allBadges = [];
  Set<String> _earnedBadgeIds = {};
  bool _isLoading = false;

  List<BadgeModel> get allBadges => _allBadges;
  Set<String> get earnedBadgeIds => _earnedBadgeIds;
  bool get isLoading => _isLoading;

  int get earnedCount => _earnedBadgeIds.length;
  int get totalCount => _allBadges.length;

  // 모든 뱃지 로드
  Future<void> loadAllBadges() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allBadges = await _badgeService.getAllBadges();
    } catch (e) {
      debugPrint('뱃지 로드 에러: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 사용자가 획득한 뱃지 로드
  Future<void> loadUserBadges(String userId) async {
    try {
      final earnedIds = await _badgeService.getUserBadgeIds(userId);
      _earnedBadgeIds = earnedIds.toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 뱃지 로드 에러: $e');
    }
  }

  // 뱃지 획득 여부 확인
  bool hasBadge(String badgeId) {
    return _earnedBadgeIds.contains(badgeId);
  }

  // 조건에 따라 뱃지 자동 획득 체크
  Future<List<BadgeModel>> checkAndEarnBadges({
    required String userId,
    required int stampCount,
    required double totalDistance,
  }) async {
    final newBadges = <BadgeModel>[];

    for (final badge in _allBadges) {
      // 이미 획득한 경우 스킵
      if (_earnedBadgeIds.contains(badge.id)) continue;

      // 조건 확인
      bool shouldEarn = false;

      switch (badge.conditionType) {
        case 'oreum_count':
          shouldEarn = stampCount >= (badge.conditionValue ?? 0);
          break;
        case 'total_distance':
          shouldEarn = totalDistance >= (badge.conditionValue ?? 0);
          break;
      }

      if (shouldEarn) {
        final success = await _badgeService.earnBadge(userId, badge.id);
        if (success) {
          _earnedBadgeIds.add(badge.id);
          newBadges.add(badge);
        }
      }
    }

    if (newBadges.isNotEmpty) {
      notifyListeners();
    }

    return newBadges;
  }

  // 뱃지 초기화 (로그아웃 시)
  void clear() {
    _earnedBadgeIds = {};
    notifyListeners();
  }
}
