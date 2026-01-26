import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/community_service.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityService _communityService = CommunityService();

  List<PostModel> _posts = [];
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  String? _error;
  String _currentFilter = '인기';
  String? _selectedCategory;
  String? _selectedOreumId;
  final Set<String> _likedPosts = {};

  List<PostModel> get posts => _posts;
  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentFilter => _currentFilter;
  String? get selectedCategory => _selectedCategory;
  String? get selectedOreumId => _selectedOreumId;

  // 카테고리 목록
  static const List<String> categories = ['전체', '등반완료', '후기', '질문', '동행모집'];

  // 게시글 목록 로드 (Supabase)
  Future<void> loadPosts({String filter = '인기'}) async {
    _isLoading = true;
    _currentFilter = filter;
    _error = null;
    notifyListeners();

    try {
      List<Map<String, dynamic>> response;

      if (filter == '인기') {
        response = await _communityService.getPostsByPopular();
      } else if (filter == '최신') {
        response = await _communityService.getPostsByLatest();
      } else {
        response = await _communityService.getPostsByLatest();
      }

      _posts = response.map((data) => PostModel.fromSupabase(data)).toList();

      // 카테고리 필터 적용
      if (_selectedCategory != null && _selectedCategory != '전체') {
        _posts = _posts.where((p) => p.category == _selectedCategory).toList();
      }

      // 오름 필터 적용
      if (_selectedOreumId != null) {
        _posts = _posts.where((p) => p.oreumId == _selectedOreumId).toList();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('게시글 로드 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 카테고리 필터 설정
  void setCategory(String? category) {
    _selectedCategory = category;
    loadPosts(filter: _currentFilter);
  }

  // 오름 필터 설정
  void setOreumFilter(String? oreumId) {
    _selectedOreumId = oreumId;
    loadPosts(filter: _currentFilter);
  }

  // 필터 초기화
  void clearFilters() {
    _selectedCategory = null;
    _selectedOreumId = null;
    loadPosts(filter: _currentFilter);
  }

  // 내 글 필터
  Future<void> loadMyPosts(String userId) async {
    _isLoading = true;
    _currentFilter = '내 글';
    notifyListeners();

    try {
      final response = await _communityService.getMyPosts();
      _posts = response.map((data) => PostModel.fromSupabase(data)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('내 게시글 로드 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 게시글 작성
  Future<bool> createPost({
    required String content,
    String? oreumId,
    String? oreumName,
    String? category,
    List<String>? images,
    String? userNickname,
    String userId = 'demo_user',
  }) async {
    try {
      await _communityService.createPost(
        content: content,
        oreumId: oreumId,
        category: category,
        images: images,
      );

      // 목록 새로고침
      await loadPosts(filter: _currentFilter);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('게시글 작성 오류: $e');
      return false;
    }
  }

  // 좋아요 토글
  Future<void> toggleLike(String postId) async {
    try {
      final isNowLiked = await _communityService.toggleLike(postId);

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index == -1) return;

      final post = _posts[index];

      if (isNowLiked) {
        _likedPosts.add(postId);
        _posts[index] = post.copyWith(likeCount: post.likeCount + 1);
      } else {
        _likedPosts.remove(postId);
        _posts[index] = post.copyWith(likeCount: post.likeCount - 1);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('좋아요 토글 오류: $e');
      // 로그인 필요 등의 오류는 UI에서 처리
    }
  }

  bool isLiked(String postId) => _likedPosts.contains(postId);

  // 좋아요 상태 확인 (Supabase)
  Future<void> checkLikeStatus(String postId) async {
    try {
      final liked = await _communityService.hasLiked(postId);
      if (liked) {
        _likedPosts.add(postId);
      } else {
        _likedPosts.remove(postId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('좋아요 상태 확인 오류: $e');
    }
  }

  // 댓글 로드
  Future<void> loadComments(String postId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _communityService.getComments(postId);
      _comments = response.map((data) => CommentModel.fromSupabase(data)).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('댓글 로드 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 게시글 삭제
  Future<bool> deletePost(String postId) async {
    try {
      await _communityService.deletePost(postId);
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('게시글 삭제 오류: $e');
      return false;
    }
  }

  // 댓글 작성
  Future<bool> addComment({
    required String postId,
    required String content,
    String? userNickname,
    String userId = 'demo_user',
  }) async {
    try {
      await _communityService.createComment(
        postId: postId,
        content: content,
      );

      // 댓글 목록 새로고침
      await loadComments(postId);

      // 게시글 댓글 수 증가
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        _posts[index] = post.copyWith(commentCount: post.commentCount + 1);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('댓글 작성 오류: $e');
      return false;
    }
  }
}
