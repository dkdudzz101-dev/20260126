import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class ReviewService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 오름별 리뷰 목록 가져오기
  Future<List<Map<String, dynamic>>> getReviewsByOreum(String oreumId) async {
    final response = await _client
        .from('reviews')
        .select('*, users(nickname, profile_image)')
        .eq('oreum_id', oreumId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 내 리뷰 목록 가져오기
  Future<List<Map<String, dynamic>>> getMyReviews() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('reviews')
        .select('*, oreums(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 리뷰 작성
  Future<void> createReview({
    required String oreumId,
    required int rating,
    String? content,
    List<String>? images,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('reviews').upsert({
      'user_id': userId,
      'oreum_id': oreumId,
      'rating': rating,
      'content': content,
      'images': images,
    });
  }

  // 리뷰 수정
  Future<void> updateReview({
    required String reviewId,
    required int rating,
    String? content,
    List<String>? images,
  }) async {
    await _client.from('reviews').update({
      'rating': rating,
      'content': content,
      'images': images,
    }).eq('id', reviewId);
  }

  // 리뷰 삭제
  Future<void> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
  }

  // 오름 평균 별점 가져오기
  Future<double> getAverageRating(String oreumId) async {
    final response = await _client
        .from('reviews')
        .select('rating')
        .eq('oreum_id', oreumId);

    final reviews = response as List;
    if (reviews.isEmpty) return 0.0;

    final total = reviews.fold<int>(0, (sum, r) => sum + (r['rating'] as int));
    return total / reviews.length;
  }

  // 내 리뷰 존재 여부 확인
  Future<Map<String, dynamic>?> getMyReview(String oreumId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('reviews')
          .select()
          .eq('user_id', userId)
          .eq('oreum_id', oreumId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }
}
