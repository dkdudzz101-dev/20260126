import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class ReportService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 신고 유형
  static const Map<String, String> reportReasons = {
    'spam': '스팸/광고',
    'inappropriate': '부적절한 내용',
    'hate': '혐오 발언',
    'harassment': '괴롭힘/따돌림',
    'misinformation': '잘못된 정보',
    'copyright': '저작권 침해',
    'other': '기타',
  };

  // 게시글 신고
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': 'post',
      'target_id': postId,
      'reason': '$reason${details != null ? ": $details" : ""}',
    });
  }

  // 댓글 신고
  Future<void> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': 'comment',
      'target_id': commentId,
      'reason': '$reason${details != null ? ": $details" : ""}',
    });
  }

  // 리뷰 신고
  Future<void> reportReview({
    required String reviewId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': 'review',
      'target_id': reviewId,
      'reason': '$reason${details != null ? ": $details" : ""}',
    });
  }

  // 사용자 신고
  Future<void> reportUser({
    required String targetUserId,
    required String reason,
    String? details,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': 'user',
      'target_id': targetUserId,
      'reason': '$reason${details != null ? ": $details" : ""}',
    });
  }

  // 일반 신고 (앱 관련 문제 등)
  Future<void> reportGeneral({
    required String reason,
    required String details,
  }) async {
    final userId = _client.auth.currentUser?.id;

    await _client.from('reports').insert({
      'reporter_id': userId,
      'target_type': 'general',
      'target_id': '00000000-0000-0000-0000-000000000000',
      'reason': '$reason: $details',
    });
  }
}
