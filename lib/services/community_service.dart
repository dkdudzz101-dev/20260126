import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class CommunityService {
  final SupabaseClient _client = SupabaseConfig.client;

  // 게시글 목록 가져오기 (인기순)
  Future<List<Map<String, dynamic>>> getPostsByPopular({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('posts')
        .select('*, users(nickname, profile_image, stamp_count), oreums(name)')
        .order('like_count', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  // 게시글 목록 가져오기 (최신순)
  Future<List<Map<String, dynamic>>> getPostsByLatest({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('posts')
        .select('*, users(nickname, profile_image, stamp_count), oreums(name)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  // 오름별 게시글 가져오기
  Future<List<Map<String, dynamic>>> getPostsByOreum(String oreumId, {int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('posts')
        .select('*, users(nickname, profile_image, stamp_count), oreums(name)')
        .eq('oreum_id', oreumId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  // 내 게시글 가져오기
  Future<List<Map<String, dynamic>>> getMyPosts() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('posts')
        .select('*, users(nickname, profile_image, stamp_count), oreums(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 게시글 상세 가져오기
  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      final response = await _client
          .from('posts')
          .select('*, users(nickname, profile_image, stamp_count), oreums(name)')
          .eq('id', postId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('게시글 조회 오류: $e');
      return null;
    }
  }

  // 게시글 작성
  Future<void> createPost({
    required String content,
    String? oreumId,
    String? category,
    List<String>? images,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('posts').insert({
      'user_id': userId,
      'content': content,
      'oreum_id': oreumId,
      'category': category,
      'images': images,
    });
  }

  // 게시글 수정
  Future<void> updatePost({
    required String postId,
    required String content,
    String? oreumId,
    String? category,
    List<String>? images,
  }) async {
    final data = <String, dynamic>{
      'content': content,
      'oreum_id': oreumId,
      'images': images,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (category != null) data['category'] = category;
    await _client.from('posts').update(data).eq('id', postId);
  }

  // 게시글 삭제
  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  // 댓글 목록 가져오기
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final response = await _client
        .from('comments')
        .select('*, users(nickname, profile_image, stamps(id))')
        .eq('post_id', postId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  // 댓글 작성
  Future<void> createComment({
    required String postId,
    required String content,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    await _client.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    });

    // 댓글 수 증가
    await _client.rpc('increment_comment_count', params: {'post_id': postId});
  }

  // 댓글 삭제
  Future<void> deleteComment(String commentId, String postId) async {
    await _client.from('comments').delete().eq('id', commentId);

    // 댓글 수 감소
    await _client.rpc('decrement_comment_count', params: {'post_id': postId});
  }

  // 좋아요 토글
  Future<bool> toggleLike(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('로그인이 필요합니다');

    // 이미 좋아요 했는지 확인
    final existing = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId);

    if ((existing as List).isNotEmpty) {
      // 좋아요 취소
      await _client
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      await _client.rpc('decrement_like_count', params: {'post_id': postId});
      return false;
    } else {
      // 좋아요 추가
      await _client.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
      await _client.rpc('increment_like_count', params: {'post_id': postId});
      return true;
    }
  }

  // 좋아요 여부 확인
  Future<bool> hasLiked(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId);

    return (response as List).isNotEmpty;
  }

  // 내가 좋아요한 게시글 ID 목록 한 번에 가져오기
  Future<Set<String>> getMyLikedPostIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final response = await _client
        .from('likes')
        .select('post_id')
        .eq('user_id', userId);

    return (response as List)
        .map((row) => row['post_id'] as String)
        .toSet();
  }

  // 이미지 업로드
  Future<String> uploadImage(String filePath, String fileName) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    await _client.storage
        .from('posts')
        .uploadBinary('images/$fileName', bytes);

    return _client.storage.from('posts').getPublicUrl('images/$fileName');
  }
}
