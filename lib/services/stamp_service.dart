import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class StampService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 스탬프 기록 저장 (stamp ID 반환) - 완등 인증용
  Future<String?> recordStamp({
    required String oreumId,
    double? distanceWalked,
    int? timeTaken,
    int? steps,
    double? avgSpeed,
    int? calories,
    double? elevationGain,
    double? elevationLoss,
    double? maxAltitude,
    double? minAltitude,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    final response = await _client.from('stamps').upsert({
      'user_id': userId,
      'oreum_id': oreumId,
      'distance_walked': distanceWalked,
      'time_taken': timeTaken,
      'steps': steps,
      'avg_speed': avgSpeed,
      'calories': calories,
      'elevation_gain': elevationGain,
      'elevation_loss': elevationLoss,
      'max_altitude': maxAltitude,
      'min_altitude': minAltitude,
      'completed_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    final stampId = response['id']?.toString();

    // 총 이동거리 업데이트
    if (distanceWalked != null) {
      await _updateTotalDistance(userId, distanceWalked);
    }

    // 뱃지 체크
    await _checkAndAwardBadges(userId);

    return stampId;
  }

  // 등반 기록 저장 (완등 여부와 무관하게 항상 저장)
  Future<String?> recordHikingLog({
    required String oreumId,
    double? distanceWalked,
    int? timeTaken,
    int? steps,
    double? avgSpeed,
    int? calories,
    double? elevationGain,
    double? elevationLoss,
    double? maxAltitude,
    double? minAltitude,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    // hiking_logs 테이블에 저장 (여러 기록 가능)
    final response = await _client.from('hiking_logs').insert({
      'user_id': userId,
      'oreum_id': oreumId,
      'distance_walked': distanceWalked,
      'time_taken': timeTaken,
      'steps': steps,
      'avg_speed': avgSpeed,
      'calories': calories,
      'elevation_gain': elevationGain,
      'elevation_loss': elevationLoss,
      'max_altitude': maxAltitude,
      'min_altitude': minAltitude,
      'hiked_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    final logId = response['id']?.toString();

    // 총 이동거리/걸음수 업데이트
    if (distanceWalked != null) {
      await _updateTotalDistance(userId, distanceWalked);
    }
    if (steps != null) {
      await _updateTotalSteps(userId, steps);
    }

    return logId;
  }

  // 총 걸음수 업데이트
  Future<void> _updateTotalSteps(String userId, int steps) async {
    try {
      final profile = await _client
          .from('users')
          .select('total_steps')
          .eq('id', userId)
          .maybeSingle();

      final currentSteps = (profile?['total_steps'] ?? 0) as num;

      await _client.from('users').update({
        'total_steps': currentSteps.toInt() + steps,
      }).eq('id', userId);
    } catch (e) {
      // 에러 무시
    }
  }

  // 사용자 스탬프 목록 가져오기
  Future<List<Map<String, dynamic>>> getUserStamps() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // stamps 가져오기
    final stamps = await _client
        .from('stamps')
        .select('*')
        .eq('user_id', userId)
        .order('completed_at', ascending: false);

    final stampList = List<Map<String, dynamic>>.from(stamps);
    if (stampList.isEmpty) return [];

    // oreum IDs 추출
    final oreumIds = stampList
        .map((s) => s['oreum_id']?.toString())
        .where((id) => id != null)
        .toSet()
        .toList();

    // oreums 데이터 가져오기
    Map<String, Map<String, dynamic>> oreumMap = {};
    if (oreumIds.isNotEmpty) {
      final oreums = await _client
          .from('oreums')
          .select('id, name, stamp_url')
          .inFilter('id', oreumIds);

      for (final oreum in oreums) {
        oreumMap[oreum['id'].toString()] = oreum;
      }
    }

    // stamps에 oreums 데이터 병합
    for (final stamp in stampList) {
      final oreumId = stamp['oreum_id']?.toString();
      if (oreumId != null && oreumMap.containsKey(oreumId)) {
        stamp['oreums'] = oreumMap[oreumId];
      }
    }

    return stampList;
  }

  // 완등 수 가져오기
  Future<int> getStampCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _client
        .from('stamps')
        .select('id')
        .eq('user_id', userId);

    return (response as List).length;
  }

  // 오름 완등 여부 확인
  Future<bool> hasStamp(String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('stamps')
        .select('id')
        .eq('user_id', userId)
        .eq('oreum_id', oreumId);

    return (response as List).isNotEmpty;
  }

  // 총 이동거리 업데이트
  Future<void> _updateTotalDistance(String userId, double distance) async {
    try {
      final profile = await _client
          .from('users')
          .select('total_distance')
          .eq('id', userId)
          .maybeSingle();

      final currentDistance = (profile?['total_distance'] ?? 0.0) as num;

      await _client.from('users').update({
        'total_distance': currentDistance.toDouble() + distance,
      }).eq('id', userId);
    } catch (e) {
      // 에러 무시 (total_distance 컬럼이 없을 수 있음)
    }
  }

  // 뱃지 체크 및 부여
  Future<void> _checkAndAwardBadges(String userId) async {
    try {
      final stampCount = await getStampCount();

      // 완등 수 기반 뱃지
      final completionBadges = {
        1: 'first_oreum',
        5: 'oreum_5',
        10: 'oreum_10',
        30: 'oreum_30',
        100: 'oreum_100',
        368: 'oreum_all',
      };

      for (final entry in completionBadges.entries) {
        if (stampCount >= entry.key) {
          await _awardBadge(userId, entry.value);
        }
      }
    } catch (e) {
      // 뱃지 체크 실패 시 무시
    }
  }

  // 뱃지 부여
  Future<void> _awardBadge(String userId, String badgeId) async {
    try {
      await _client.from('user_badges').upsert({
        'user_id': userId,
        'badge_id': badgeId,
      });
    } catch (e) {
      // 이미 보유한 뱃지면 무시
    }
  }

  // 사용자 뱃지 목록 가져오기
  Future<List<Map<String, dynamic>>> getUserBadges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('user_badges')
        .select('*, badges(*)')
        .eq('user_id', userId)
        .order('earned_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 모든 뱃지 가져오기
  Future<List<Map<String, dynamic>>> getAllBadges() async {
    final response = await _client
        .from('badges')
        .select()
        .order('condition_value');

    return List<Map<String, dynamic>>.from(response);
  }

  // 총 이동거리 가져오기 (stamps 테이블에서 합산)
  Future<double> getTotalDistance() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0.0;

    try {
      final response = await _client
          .from('stamps')
          .select('distance_walked')
          .eq('user_id', userId);

      double total = 0.0;
      for (final row in response) {
        final distance = row['distance_walked'];
        if (distance != null) {
          total += (distance as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // 총 걸음수 가져오기 (stamps 테이블에서 합산)
  Future<int> getTotalSteps() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _client
          .from('stamps')
          .select('steps')
          .eq('user_id', userId);

      int total = 0;
      for (final row in response) {
        final steps = row['steps'];
        if (steps != null) {
          total += (steps as num).toInt();
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}
