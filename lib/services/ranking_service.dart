import '../config/supabase_config.dart';

class RankingUser {
  final String userId;
  final String nickname;
  final String? profileImage;
  final int stampCount;
  final int rank;

  RankingUser({
    required this.userId,
    required this.nickname,
    this.profileImage,
    required this.stampCount,
    required this.rank,
  });

  int get level => stampCount;
}

class RankingService {
  static final _client = SupabaseConfig.client;

  /// 전체 랭킹 조회 (완등 수 기준, 상위 limit명)
  static Future<List<RankingUser>> getRanking({int limit = 100}) async {
    try {
      // stamps 테이블에서 user_id별 완등 수 집계
      final response = await _client
          .from('stamps')
          .select('user_id');

      // user_id별 카운트
      final Map<String, int> countMap = {};
      for (final row in response) {
        final uid = row['user_id'] as String;
        countMap[uid] = (countMap[uid] ?? 0) + 1;
      }

      if (countMap.isEmpty) return [];

      // 유저 정보 가져오기
      final userIds = countMap.keys.toList();
      final users = await _client
          .from('users')
          .select('id, nickname, profile_image')
          .inFilter('id', userIds);

      final Map<String, Map<String, dynamic>> userMap = {};
      for (final u in users) {
        userMap[u['id'] as String] = u;
      }

      // 정렬 (완등 수 내림차순)
      final sorted = countMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final result = <RankingUser>[];
      int rank = 1;
      int prevCount = -1;

      for (final entry in sorted) {
        if (result.length >= limit) break;

        if (entry.value != prevCount) {
          rank = result.length + 1;
          prevCount = entry.value;
        }

        final user = userMap[entry.key];
        result.add(RankingUser(
          userId: entry.key,
          nickname: user?['nickname'] as String? ?? '탐험가',
          profileImage: user?['profile_image'] as String?,
          stampCount: entry.value,
          rank: rank,
        ));
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// 내 순위 가져오기
  static Future<int?> getMyRank() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('stamps')
          .select('user_id');

      final Map<String, int> countMap = {};
      for (final row in response) {
        final uid = row['user_id'] as String;
        countMap[uid] = (countMap[uid] ?? 0) + 1;
      }

      if (!countMap.containsKey(userId)) return null;

      final myCount = countMap[userId]!;
      // 나보다 완등 수가 많은 유저 수 + 1 = 내 순위
      final higherCount = countMap.values.where((c) => c > myCount).length;
      return higherCount + 1;
    } catch (e) {
      return null;
    }
  }
}
