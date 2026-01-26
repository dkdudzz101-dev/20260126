import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class OfflineService {
  final SupabaseClient _client = SupabaseConfig.client;
  static const int dailyDownloadLimit = 3;

  // 오늘 다운로드 횟수 확인
  Future<int> getTodayDownloadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await _client
        .from('offline_downloads')
        .select('id')
        .eq('user_id', userId)
        .eq('downloaded_at', today);

    return (response as List).length;
  }

  // 다운로드 가능 여부 확인
  Future<bool> canDownload() async {
    final count = await getTodayDownloadCount();
    return count < dailyDownloadLimit;
  }

  // 남은 다운로드 횟수
  Future<int> getRemainingDownloads() async {
    final count = await getTodayDownloadCount();
    return dailyDownloadLimit - count;
  }

  // 다운로드 기록 저장
  Future<bool> recordDownload(String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    // 다운로드 가능 여부 확인
    if (!await canDownload()) {
      throw Exception('오늘 다운로드 한도를 초과했습니다 (최대 $dailyDownloadLimit회/일)');
    }

    // 이미 다운로드한 오름인지 확인 (오늘)
    final today = DateTime.now().toIso8601String().split('T')[0];
    final existing = await _client
        .from('offline_downloads')
        .select('id')
        .eq('user_id', userId)
        .eq('oreum_id', oreumId)
        .eq('downloaded_at', today);

    if ((existing as List).isNotEmpty) {
      // 이미 오늘 다운로드함
      return true;
    }

    // 다운로드 기록 추가
    await _client.from('offline_downloads').insert({
      'user_id': userId,
      'oreum_id': oreumId,
    });

    return true;
  }

  // 다운로드한 오름 목록
  Future<List<Map<String, dynamic>>> getDownloadedOreums() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('offline_downloads')
        .select('*, oreums(*)')
        .eq('user_id', userId)
        .order('downloaded_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 특정 오름 다운로드 여부 확인 (전체 기간)
  Future<bool> isDownloaded(String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('offline_downloads')
        .select('id')
        .eq('user_id', userId)
        .eq('oreum_id', oreumId);

    return (response as List).isNotEmpty;
  }

  // GeoJSON 파일 URL 가져오기
  String getGeojsonUrl(String oreumId) {
    return _client.storage.from('oreum-data').getPublicUrl('$oreumId/trail.geojson');
  }

  // GeoJSON 파일 다운로드
  Future<String?> downloadGeojson(String oreumId) async {
    try {
      final response = await _client.storage.from('oreum-data').download('$oreumId/trail.geojson');
      return String.fromCharCodes(response);
    } catch (e) {
      return null;
    }
  }

  // 오름 전체 데이터 다운로드 (이미지, GeoJSON, 고도표)
  Future<Map<String, dynamic>> downloadOreumData(String oreumId) async {
    final data = <String, dynamic>{};

    try {
      // GeoJSON
      final geojson = await _client.storage.from('oreum-data').download('$oreumId/trail.geojson');
      data['geojson'] = String.fromCharCodes(geojson);
    } catch (e) {
      data['geojson'] = null;
    }

    // 이미지 URL은 오프라인에서도 캐시로 사용 가능
    data['mainImageUrl'] = _client.storage.from('oreum-data').getPublicUrl('$oreumId/main.jpg');
    data['elevationUrl'] = _client.storage.from('oreum-data').getPublicUrl('$oreumId/elevation.png');

    return data;
  }
}
