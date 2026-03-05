import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'oreum_service.dart';

class StampService {
  final SupabaseClient _client = SupabaseConfig.client;
  final OreumService _oreumService = OreumService();

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
    double? descentDistance,
    int? descentTime,
    int? descentSteps,
    int? descentCalories,
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
      'descent_distance': descentDistance,
      'descent_time': descentTime,
      'descent_steps': descentSteps,
      'descent_calories': descentCalories,
      'completed_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,oreum_id').select('id').single();

    final stampId = response['id']?.toString();

    // 총 이동거리 업데이트 (등산 + 하산)
    final totalDist = (distanceWalked ?? 0) + (descentDistance ?? 0);
    if (totalDist > 0) {
      await _updateTotalDistance(userId, totalDist);
    }

    // 총 걸음수 업데이트 (등산 + 하산)
    final totalSteps = (steps ?? 0) + (descentSteps ?? 0);
    if (totalSteps > 0) {
      await _updateTotalSteps(userId, totalSteps);
    }

    // 뱃지 체크
    await _checkAndAwardBadges(userId);

    // 등산로 점검 상태를 '점검완료'로 변경
    try {
      await _oreumService.updateTrailStatus(oreumId, 'verified');
    } catch (e) {
      // 점검 상태 업데이트 실패 시 무시
    }

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
    double? descentDistance,
    int? descentTime,
    int? descentSteps,
    int? descentCalories,
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
      'descent_distance': descentDistance,
      'descent_time': descentTime,
      'descent_steps': descentSteps,
      'descent_calories': descentCalories,
      'hiked_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    final logId = response['id']?.toString();

    // 총 이동거리/걸음수 업데이트 (등산 + 하산)
    final totalDist = (distanceWalked ?? 0) + (descentDistance ?? 0);
    if (totalDist > 0) {
      await _updateTotalDistance(userId, totalDist);
    }
    final totalSteps = (steps ?? 0) + (descentSteps ?? 0);
    if (totalSteps > 0) {
      await _updateTotalSteps(userId, totalSteps);
    }

    // 등산로 점검 상태를 '점검완료'로 변경
    try {
      await _oreumService.updateTrailStatus(oreumId, 'verified');
    } catch (e) {
      // 점검 상태 업데이트 실패 시 무시
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

  // 사용자 스탬프 목록 가져오기 (stamps + hiking_logs 통합)
  Future<List<Map<String, dynamic>>> getUserStamps() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // stamps 가져오기
    final stamps = await _client
        .from('stamps')
        .select('*')
        .eq('user_id', userId);

    // hiking_logs 가져오기
    final hikingLogs = await _client
        .from('hiking_logs')
        .select('*')
        .eq('user_id', userId);

    // 통합 리스트 생성
    final List<Map<String, dynamic>> allRecords = [];

    // stamps 추가 (completed_at 기준)
    for (final stamp in stamps) {
      final record = Map<String, dynamic>.from(stamp);
      record['record_type'] = 'stamp';
      record['record_date'] = stamp['completed_at'];
      allRecords.add(record);
    }

    // hiking_logs 추가 (hiked_at 기준)
    for (final log in hikingLogs) {
      final record = Map<String, dynamic>.from(log);
      record['record_type'] = 'hiking_log';
      record['record_date'] = log['hiked_at'];
      allRecords.add(record);
    }

    if (allRecords.isEmpty) return [];

    // 날짜순 정렬 (최신순)
    allRecords.sort((a, b) {
      final dateA = DateTime.tryParse(a['record_date'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['record_date'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    // oreum IDs 추출
    final oreumIds = allRecords
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

    // records에 oreums 데이터 병합
    for (final record in allRecords) {
      final oreumId = record['oreum_id']?.toString();
      if (oreumId != null && oreumMap.containsKey(oreumId)) {
        record['oreums'] = oreumMap[oreumId];
      }
    }

    return allRecords;
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

  // 총 이동거리 가져오기 (stamps + hiking_logs 합산)
  Future<double> getTotalDistance() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0.0;

    try {
      double total = 0.0;

      // stamps 거리
      final stamps = await _client
          .from('stamps')
          .select('distance_walked, descent_distance')
          .eq('user_id', userId);
      for (final row in stamps) {
        if (row['distance_walked'] != null) total += (row['distance_walked'] as num).toDouble();
        if (row['descent_distance'] != null) total += (row['descent_distance'] as num).toDouble();
      }

      // hiking_logs 거리
      final logs = await _client
          .from('hiking_logs')
          .select('distance_walked, descent_distance')
          .eq('user_id', userId);
      for (final row in logs) {
        if (row['distance_walked'] != null) total += (row['distance_walked'] as num).toDouble();
        if (row['descent_distance'] != null) total += (row['descent_distance'] as num).toDouble();
      }

      return total;
    } catch (e) {
      return 0.0;
    }
  }

  // 총 걸음수 가져오기 (stamps + hiking_logs 합산)
  Future<int> getTotalSteps() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      int total = 0;

      // stamps 걸음수
      final stamps = await _client
          .from('stamps')
          .select('steps, descent_steps')
          .eq('user_id', userId);
      for (final row in stamps) {
        if (row['steps'] != null) total += (row['steps'] as num).toInt();
        if (row['descent_steps'] != null) total += (row['descent_steps'] as num).toInt();
      }

      // hiking_logs 걸음수
      final logs = await _client
          .from('hiking_logs')
          .select('steps, descent_steps')
          .eq('user_id', userId);
      for (final row in logs) {
        if (row['steps'] != null) total += (row['steps'] as num).toInt();
        if (row['descent_steps'] != null) total += (row['descent_steps'] as num).toInt();
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  // 최근 기록에 메모 추가
  Future<void> updateLatestRecordMemo({
    required String oreumId,
    required String memo,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // stamps에서 최근 기록 찾기
    try {
      final stamp = await _client
          .from('stamps')
          .select('id')
          .eq('user_id', userId)
          .eq('oreum_id', oreumId)
          .maybeSingle();

      if (stamp != null) {
        await _client.from('stamps').update({'memo': memo}).eq('id', stamp['id']);
        return;
      }
    } catch (_) {}

    // hiking_logs에서 최근 기록 찾기
    try {
      final log = await _client
          .from('hiking_logs')
          .select('id')
          .eq('user_id', userId)
          .eq('oreum_id', oreumId)
          .order('hiked_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (log != null) {
        await _client.from('hiking_logs').update({'memo': memo}).eq('id', log['id']);
      }
    } catch (_) {}
  }

  // 특정 오름의 인증자 목록 (순위 포함, 완등 시각 순)
  Future<List<Map<String, dynamic>>> getOreumStampUsers(String oreumId) async {
    try {
      final response = await _client
          .from('stamps')
          .select('user_id, completed_at, users(nickname, profile_image)')
          .eq('oreum_id', oreumId)
          .order('completed_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
