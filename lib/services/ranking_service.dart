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

  /// 전체 랭킹 조회 (완등 수 기준, 상위 limit명) - RPC 사용
  static Future<List<RankingUser>> getRanking({int limit = 100}) async {
    try {
      final response = await _client.rpc('get_user_ranking', params: {
        'p_limit': limit,
      });

      final List data = response as List;
      return data.map((row) => RankingUser(
        userId: row['user_id'] as String,
        nickname: row['nickname'] as String? ?? '탐험가',
        profileImage: row['profile_image'] as String?,
        stampCount: (row['stamp_count'] as num).toInt(),
        rank: (row['rank'] as num).toInt(),
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// 오름별 인기 순위 (인증 많은 순) - RPC 사용
  static Future<List<Map<String, dynamic>>> getOreumRanking({int limit = 100}) async {
    try {
      final response = await _client.rpc('get_oreum_ranking', params: {
        'p_limit': limit,
      });

      final List data = response as List;
      return data.map((row) => <String, dynamic>{
        'oreum_id': row['oreum_id'] as String,
        'name': row['name'] as String? ?? '알 수 없는 오름',
        'count': (row['stamp_count'] as num).toInt(),
        'rank': (row['rank'] as num).toInt(),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 특정 오름 인증자 목록
  static Future<List<RankingUser>> getOreumCertifiers(String oreumId) async {
    try {
      final response = await _client
          .from('stamps')
          .select('user_id, created_at')
          .eq('oreum_id', oreumId)
          .order('created_at');

      if ((response as List).isEmpty) return [];

      final userIds = response.map((r) => r['user_id'] as String).toSet().toList();
      final users = await _client
          .from('users')
          .select('id, nickname, profile_image')
          .inFilter('id', userIds);

      final Map<String, Map<String, dynamic>> userMap = {};
      for (final u in users) {
        userMap[u['id'] as String] = u;
      }

      final result = <RankingUser>[];
      int rank = 1;
      for (final uid in userIds) {
        final user = userMap[uid];
        result.add(RankingUser(
          userId: uid,
          nickname: user?['nickname'] as String? ?? '탐험가',
          profileImage: user?['profile_image'] as String?,
          stampCount: 1,
          rank: rank++,
        ));
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// 내 순위 가져오기 - RPC 사용
  static Future<int?> getMyRank() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client.rpc('get_my_rank', params: {
        'p_user_id': userId,
      });

      if (response == null) return null;
      return (response as num).toInt();
    } catch (e) {
      return null;
    }
  }
}
