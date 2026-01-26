import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class NotificationService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 알림 목록 가져오기
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // 읽지 않은 알림 수
  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  // 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    await _client.from('notifications').update({
      'is_read': true,
    }).eq('id', notificationId);
  }

  // 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('notifications').update({
      'is_read': true,
    }).eq('user_id', userId).eq('is_read', false);
  }

  // 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
  }

  // 모든 알림 삭제
  Future<void> deleteAllNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('notifications').delete().eq('user_id', userId);
  }

  // 알림 생성 (서버 사이드에서 호출, 클라이언트에서는 테스트용)
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    String? message,
    Map<String, dynamic>? data,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
    });
  }
}
