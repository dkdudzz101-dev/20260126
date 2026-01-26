import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class HikingRouteService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// GPS 경로 저장 (stamp_id 또는 hiking_log_id 중 하나 필요)
  Future<String?> saveRoute({
    String? stampId,
    String? hikingLogId,
    required String oreumId,
    required List<Position> positions,
    List<String>? photoUrls,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    if (positions.isEmpty) {
      debugPrint('저장할 경로 데이터가 없습니다');
      return null;
    }

    // Position 리스트를 JSON 배열로 변환
    final routeData = positions.map((p) => {
      'lat': p.latitude,
      'lng': p.longitude,
      'altitude': p.altitude,
      'timestamp': p.timestamp?.toIso8601String(),
      'accuracy': p.accuracy,
      'speed': p.speed,
    }).toList();

    final insertData = <String, dynamic>{
      'user_id': userId,
      'oreum_id': oreumId,
      'route_data': routeData,
    };

    if (stampId != null) {
      insertData['stamp_id'] = stampId;
    }
    if (hikingLogId != null) {
      insertData['hiking_log_id'] = hikingLogId;
    }
    if (photoUrls != null && photoUrls.isNotEmpty) {
      insertData['photo_urls'] = photoUrls;
    }

    final response = await _client.from('hiking_routes').insert(insertData).select('id').single();

    debugPrint('경로 저장 완료: ${positions.length}개 포인트');
    return response['id']?.toString();
  }

  /// 등반 사진 업로드
  Future<String> uploadHikingPhoto(String filePath, String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_${oreumId}_$timestamp.jpg';

    await _client.storage
        .from('hiking-photos')
        .uploadBinary(fileName, bytes);

    return _client.storage.from('hiking-photos').getPublicUrl(fileName);
  }

  /// 경로 조회 (stamp_id로)
  Future<List<Map<String, dynamic>>?> getRoute(String stampId) async {
    try {
      final response = await _client
          .from('hiking_routes')
          .select('route_data')
          .eq('stamp_id', stampId)
          .maybeSingle();

      if (response != null && response['route_data'] != null) {
        return List<Map<String, dynamic>>.from(response['route_data']);
      }
      return null;
    } catch (e) {
      debugPrint('경로 조회 오류: $e');
      return null;
    }
  }

  /// 경로 및 사진 조회 (stamp_id로)
  Future<Map<String, dynamic>?> getRouteWithPhotos(String stampId) async {
    try {
      final response = await _client
          .from('hiking_routes')
          .select('route_data, photo_urls')
          .eq('stamp_id', stampId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('경로/사진 조회 오류: $e');
      return null;
    }
  }

  /// hiking_log_id로 경로 조회
  Future<Map<String, dynamic>?> getRouteByLogId(String logId) async {
    try {
      final response = await _client
          .from('hiking_routes')
          .select('route_data, photo_urls')
          .eq('hiking_log_id', logId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('경로 조회 오류 (log_id): $e');
      return null;
    }
  }

  /// 사용자의 모든 경로 조회
  Future<List<Map<String, dynamic>>> getUserRoutes() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('hiking_routes')
          .select('*, stamps(oreum_id, completed_at), hiking_logs(oreum_id, hiked_at)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('사용자 경로 조회 오류: $e');
      return [];
    }
  }

  /// 경로 삭제
  Future<void> deleteRoute(String stampId) async {
    await _client.from('hiking_routes').delete().eq('stamp_id', stampId);
  }
}
